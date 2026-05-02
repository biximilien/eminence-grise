# frozen_string_literal: true

require "json"
require "open3"
require "time"

module EminenceGrise
  class CliAgent
    Result = Struct.new(:task, :instruction, :stdout, :stderr, :status, :retry_at, keyword_init: true)
    SpawnFailureStatus = Struct.new(:error, keyword_init: true) do
      def success?
        false
      end
    end

    class ExecutionError < StandardError
      attr_reader :result

      def initialize(result, command_name: "cli")
        @result = result
        super("#{command_name} failed for #{result.task.id}: #{CliAgent.failure_summary(result.stdout, result.stderr)}")
      end

      def retry_at
        result.retry_at
      end
    end

    def initialize(command:, working_directory: Dir.pwd, extra_args: [], stream: false, stdout: $stdout, stderr: $stderr, executor: nil)
      @command = command
      @working_directory = working_directory
      @extra_args = extra_args
      @stream_stdout = stream ? stdout : nil
      @stream_stderr = stream ? stderr : nil
      @executor = executor || (stream ? method(:capture_streaming) : method(:capture))
    end

    def call(task)
      instruction = instruction_for(task)
      command = command_for(instruction)
      stdout, stderr, status = @executor.call(command, stdin_for(instruction), working_directory: working_directory)
      result = Result.new(
        task: task,
        instruction: instruction,
        stdout: stdout,
        stderr: stderr,
        status: status,
        retry_at: retry_at_for(stdout, stderr)
      )

      raise execution_error(result) unless status.success?

      result
    rescue SystemCallError => error
      result = Result.new(
        task: task,
        instruction: instruction,
        stdout: "",
        stderr: self.class.spawn_failure_message(command, error),
        status: SpawnFailureStatus.new(error: error),
        retry_at: nil
      )
      raise execution_error(result)
    end

    def self.failure_summary(stdout, stderr)
      lines = [stderr, stdout].compact.join("\n").lines.filter_map do |line|
        normalized = line.strip
        next if normalized.empty?

        normalized = normalized.sub(/:?\s*<html>.*/i, "")
        next if normalized.empty? || normalized.start_with?("<") || normalized.include?("</")

        normalized
      end

      actionable = lines.select do |line|
        line.match?(/(^ERROR\b|usage limit|rate limit|try again|resume|reset|available)/i)
      end
      contextual = lines.select do |line|
        line.match?(/(failed with status|forbidden|authentication|login|no prompt)/i)
      end
      summary_lines = (actionable.empty? ? contextual : actionable)
      summary_lines = lines if summary_lines.empty?

      summary = summary_lines.uniq.first(3).join(" | ")
      summary = "command exited unsuccessfully" if summary.empty?
      summary.length > 1_000 ? "#{summary[0, 997]}..." : summary
    end

    def self.spawn_failure_message(command, error)
      command_name = Array(command).first || "command"

      case error
      when Errno::ENOENT
        "command not found: #{command_name} (#{error.message})"
      else
        "could not start command #{command_name}: #{error.message}"
      end
    end

    private

    attr_reader :command, :working_directory, :extra_args

    def command_for(_instruction)
      raise NotImplementedError, "#{self.class} must implement #command_for"
    end

    def command_name
      command
    end

    def execution_error(result)
      ExecutionError.new(result, command_name: command_name)
    end

    def instruction_for(task)
      parts = [
        "Task ID: #{task.id}",
        "Title: #{task.title}"
      ]
      parts << "Description:\n#{task.description}" if task.description
      parts << "Metadata:\n#{JSON.pretty_generate(task.metadata)}" unless task.metadata.empty?
      parts.join("\n\n")
    end

    def stdin_for(instruction)
      instruction
    end

    def capture(command, stdin_data, working_directory:)
      options = { chdir: working_directory }
      options[:stdin_data] = stdin_data unless stdin_data.nil?
      Open3.capture3(*command, **options)
    end

    def capture_streaming(command, stdin_data, working_directory:)
      stdout_chunks = []
      stderr_chunks = []
      status = nil

      Open3.popen3(*command, chdir: working_directory) do |stdin, stdout, stderr, wait_thread|
        stdin.write(stdin_data) unless stdin_data.nil?
        stdin.close

        readers = [
          Thread.new { pump(stdout, @stream_stdout, stdout_chunks) },
          Thread.new { pump(stderr, @stream_stderr, stderr_chunks) }
        ]
        readers.each(&:join)
        status = wait_thread.value
      end

      [stdout_chunks.join, stderr_chunks.join, status]
    end

    def pump(input, output, chunks)
      loop do
        chunk = input.readpartial(4096)
        chunks << chunk
        output&.write(chunk)
        output&.flush if output&.respond_to?(:flush)
      end
    rescue EOFError
      nil
    end

    def retry_at_for(stdout, stderr)
      [stdout, stderr].join("\n").lines.each do |line|
        next unless retry_line?(line)

        timestamp = timestamp_from(line)
        return timestamp if timestamp
      end

      nil
    end

    def retry_line?(line)
      line.match?(/retry|try again|resume|reset|available|rate limit|usage limit/i)
    end

    def timestamp_from(line)
      iso_timestamp_from(line) || natural_timestamp_from(line)
    end

    def iso_timestamp_from(line)
      match = line.match(/\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}(?::\d{2})?(?:\s?(?:Z|[+-]\d{2}:?\d{2}))?/)
      parse_time(match[0]) if match
    end

    def natural_timestamp_from(line)
      match = line.match(/(?:at|until|after)\s+(.+)$/i)
      parse_time(match[1]) if match
    end

    def parse_time(value)
      Time.parse(value.gsub(/\bUTC\b/i, "+00:00"))
    rescue ArgumentError
      nil
    end
  end
end
