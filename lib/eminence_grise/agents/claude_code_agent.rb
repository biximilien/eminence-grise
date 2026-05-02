# frozen_string_literal: true

require_relative "cli_agent"

module EminenceGrise
  class ClaudeCodeAgent < CliAgent
    Result = CliAgent::Result

    class ExecutionError < CliAgent::ExecutionError
      def initialize(result)
        super(result, command_name: "claude")
      end
    end

    def initialize(
      command: "claude",
      working_directory: Dir.pwd,
      model: nil,
      permission_mode: nil,
      output_format: "text",
      extra_args: [],
      stream: false,
      stdout: $stdout,
      stderr: $stderr,
      executor: nil
    )
      @model = model
      @permission_mode = permission_mode
      @output_format = output_format
      super(
        command: command,
        working_directory: working_directory,
        extra_args: extra_args,
        stream: stream,
        stdout: stdout,
        stderr: stderr,
        executor: executor
      )
    end

    private

    def command_for(instruction)
      [command, "-p", "--output-format", @output_format].tap do |args|
        args.push("--model", @model) if @model
        args.push("--permission-mode", @permission_mode) if @permission_mode
        args.concat(extra_args)
        args.push(instruction)
      end
    end

    def execution_error(result)
      ExecutionError.new(result)
    end
  end
end
