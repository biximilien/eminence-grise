# frozen_string_literal: true

require "fileutils"

require "eminence_grise"

$stdout.sync = true
$stderr.sync = true

output_path = ".eminence-grise/codex-last-message.txt"
FileUtils.mkdir_p(File.dirname(output_path))

queue = EminenceGrise::MemoryQueue.new([
  EminenceGrise::Task.new(
    id: "task-1",
    title: "Inspect the project",
    description: "Read the repository and print a short architecture summary. Do not modify files."
  )
])

codex = EminenceGrise::CodexAgent.new(
  working_directory: Dir.pwd,
  sandbox: "read-only",
  approval_policy: "never",
  output_last_message: output_path
)

agent = EminenceGrise::Agent.new do |task|
  FileUtils.rm_f(output_path)
  result = codex.call(task)
  message = File.exist?(output_path) ? File.read(output_path) : result.stdout
  puts message unless message.empty?
  warn "codex elapsed_seconds=#{format('%.2f', result.elapsed_seconds)}"
  warn "codex usage=#{result.usage.inspect}" unless result.usage.empty?
  result
end

runner = EminenceGrise::Runner.new(
  queue: queue,
  agent: agent,
  logger: EminenceGrise::Logging.console,
  wait_on_retry_at: false
)

begin
  runner.run
rescue EminenceGrise::CliAgent::ExecutionError => error
  warn error.message
  warn "codex elapsed_seconds=#{format('%.2f', error.result.elapsed_seconds)}" if error.result.elapsed_seconds
  warn "codex usage=#{error.result.usage.inspect}" unless error.result.usage.empty?
  exit 1
end
