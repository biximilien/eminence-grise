# frozen_string_literal: true

require "fileutils"
require "json"
require "time"

require "eminence_grise"

$stdout.sync = true
$stderr.sync = true

# Example-local JSON queue. This is intentionally not a stable queue adapter yet.
class JsonTaskQueue
  attr_reader :root, :queued_dir, :processing_dir, :done_dir, :failed_dir

  def initialize(root:)
    @root = root
    @queued_dir = File.join(root, "queued")
    @processing_dir = File.join(root, "processing")
    @done_dir = File.join(root, "done")
    @failed_dir = File.join(root, "failed")
    prepare
    recover_processing_tasks
  end

  def pop
    path = Dir.glob(File.join(@queued_dir, "*.json")).sort.first
    return unless path

    processing_path = File.join(@processing_dir, File.basename(path))
    FileUtils.mv(path, processing_path)
    [task_from(processing_path), processing_path]
  rescue JSON::ParserError, KeyError, TypeError => error
    fail(processing_path, error) if processing_path
    nil
  rescue Errno::ENOENT
    nil
  end

  def complete(path)
    archive(path, @done_dir)
  end

  def fail(path, error)
    failed_path = archive(path, @failed_dir)
    File.write("#{failed_path}.error.txt", "#{error.class}: #{error.message}\n#{Array(error.backtrace).join("\n")}\n")
  end

  private

  def prepare
    [@queued_dir, @processing_dir, @done_dir, @failed_dir].each { |path| FileUtils.mkdir_p(path) }
  end

  def recover_processing_tasks
    Dir.glob(File.join(@processing_dir, "*.json")).each do |path|
      FileUtils.mv(path, File.join(@queued_dir, File.basename(path)))
    end
  end

  def task_from(path)
    EminenceGrise::TaskPayload.call(JSON.parse(File.read(path)))
  end

  def archive(path, directory)
    target = File.join(directory, "#{timestamp}-#{File.basename(path)}")
    FileUtils.mv(path, target)
    target
  end

  def timestamp
    Time.now.utc.strftime("%Y%m%d%H%M%S")
  end
end

queue_root = ENV.fetch("QUEUE_ROOT", ".eminence-grise/production_queue")
poll_interval = Float(ENV.fetch("POLL_INTERVAL", "5"))
max_tasks = ENV["MAX_TASKS"]&.to_i
stop_file = File.join(queue_root, "stop")
logger = EminenceGrise::Logging.console
task_queue = JsonTaskQueue.new(root: queue_root)
running = true
processed = 0

Signal.trap("INT") { running = false }
Signal.trap("TERM") { running = false }

agent = EminenceGrise::Agent.new do |task|
  puts "Processing #{task.id}: #{task.title}"
  puts task.description if task.description
end

logger.info("production loop started queue=#{queue_root}")
logger.info("enqueue tasks by writing JSON files to #{task_queue.queued_dir}")

while running && !File.exist?(stop_file)
  item = task_queue.pop

  unless item
    sleep poll_interval
    next
  end

  task, path = item
  runner = EminenceGrise::Runner.new(
    queue: EminenceGrise::MemoryQueue.new([task]),
    agent: agent,
    logger: logger
  )

  begin
    runner.run
    task_queue.complete(path)
  rescue StandardError => error
    task_queue.fail(path, error)
    logger.error("task archived as failed id=#{task.id} error=#{error.message.inspect}")
  end

  processed += 1
  break if max_tasks && processed >= max_tasks
end

logger.info("production loop stopped queue=#{queue_root}")
