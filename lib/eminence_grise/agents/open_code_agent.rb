# frozen_string_literal: true

require_relative "cli_agent"

module EminenceGrise
  # CLI agent for OpenCode.
  #
  # Runs `opencode run` and passes the generated task instruction as the final
  # command argument.
  class OpenCodeAgent < CliAgent
    # Alias for the shared CLI result type.
    Result = CliAgent::Result

    # Raised when `opencode` fails.
    class ExecutionError < CliAgent::ExecutionError
      def initialize(result)
        super(result, command_name: "opencode")
      end
    end

    # @param command [String] OpenCode executable name or path
    # @param working_directory [String] workspace directory
    # @param model [String, nil] optional OpenCode model
    # @param agent [String, nil] optional OpenCode agent name
    # @param output_format [String, nil] optional OpenCode output format
    # @param extra_args [Array<String>] extra OpenCode arguments
    # @param stream [Boolean] whether to stream OpenCode stdout/stderr
    # @param stdout [IO, nil] stream target for stdout
    # @param stderr [IO, nil] stream target for stderr
    # @param observer [#call, nil] optional structured event observer
    # @param executor [#call, nil] test seam for command execution
    def initialize(
      command: "opencode",
      working_directory: Dir.pwd,
      model: nil,
      agent: nil,
      output_format: nil,
      extra_args: [],
      stream: false,
      stdout: $stdout,
      stderr: $stderr,
      observer: nil,
      executor: nil
    )
      @model = model
      @agent = agent
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
      [command, "run"].tap do |args|
        args.push("--model", @model) if @model
        args.push("--agent", @agent) if @agent
        args.push("--format", @output_format) if @output_format
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
