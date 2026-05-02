# frozen_string_literal: true

require "json"
require "open3"
require "time"

module EminenceGrise
  class CodexAgent
    Result = Struct.new(:task, :instruction, :stdout, :stderr, :status, :retry_at, keyword_init: true)

    class ExecutionError < StandardError
      attr_reader :result

      def initialize(result)
        @result = result
        super("codex exec failed for #{result.task.id}: #{result.stderr}")
      end

      def retry_at
        result.retry_at
      end
    end

    def initialize(
      command: "codex",
      working_directory: Dir.pwd,
      model: nil,
      sandbox: "workspace-write",
      approval_policy: "never",
      extra_args: [],
      executor: nil
    )
      @command = command
      @working_directory = working_directory
      @model = model
      @sandbox = sandbox
      @approval_policy = approval_policy
      @extra_args = extra_args
      @executor = executor || method(:capture)
    end

    def call(task)
      instruction = instruction_for(task)
      stdout, stderr, status = @executor.call(command_for, instruction)
      result = Result.new(
        task: task,
        instruction: instruction,
        stdout: stdout,
        stderr: stderr,
        status: status,
        retry_at: retry_at_for(stdout, stderr)
      )

      raise ExecutionError, result unless status.success?

      result
    end

    private

    def command_for
      [@command, "exec", "-C", @working_directory, "--sandbox", @sandbox, "--ask-for-approval", @approval_policy].tap do |args|
        args.push("--model", @model) if @model
        args.concat(@extra_args)
        args.push("-")
      end
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

    def capture(command, instruction)
      Open3.capture3(*command, stdin_data: instruction)
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
