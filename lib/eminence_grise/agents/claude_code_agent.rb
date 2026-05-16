# frozen_string_literal: true

require_relative "cli_agent"

module EminenceGrise
  # CLI agent for Claude Code.
  #
  # Runs `claude -p` and passes the generated task instruction as the final
  # command argument.
  class ClaudeCodeAgent < CliAgent
    # Alias for the shared CLI result type.
    Result = CliAgent::Result

    # Raised when `claude` fails.
    class ExecutionError < CliAgent::ExecutionError
      def initialize(result)
        super(result, command_name: "claude")
      end
    end

    # @param command [String] Claude executable name or path
    # @param working_directory [String] workspace directory
    # @param model [String, nil] optional Claude model
    # @param permission_mode [String, nil] optional Claude permission mode
    # @param output_format [String] Claude output format
    # @param extra_args [Array<String>] extra Claude arguments
    # @param stream [Boolean] whether to stream Claude stdout/stderr
    # @param stdout [IO, nil] stream target for stdout
    # @param stderr [IO, nil] stream target for stderr
    # @param observer [#call, nil] optional structured event observer
    # @param executor [#call, nil] test seam for command execution
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
      observer: nil,
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
        observer: observer,
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

    def stdin_for(_instruction)
      nil
    end

    def execution_error(result)
      ExecutionError.new(result)
    end
  end
end
