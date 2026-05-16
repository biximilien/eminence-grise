# frozen_string_literal: true

require_relative "cli_agent"

module EminenceGrise
  # CLI agent for Codex CLI.
  #
  # Runs `codex exec` and sends the generated task instruction on stdin.
  class CodexAgent < CliAgent
    # Alias for the shared CLI result type.
    Result = CliAgent::Result

    # Raised when `codex exec` fails.
    class ExecutionError < CliAgent::ExecutionError
      def initialize(result)
        super(result, command_name: "codex exec")
      end
    end

    # @param command [String] Codex executable name or path
    # @param working_directory [String] workspace directory
    # @param model [String, nil] optional Codex model
    # @param sandbox [String] Codex sandbox mode
    # @param approval_policy [String, nil] Codex approval policy
    # @param output_last_message [String, nil] optional path for Codex final message output
    # @param extra_args [Array<String>] extra Codex arguments
    # @param stream [Boolean] whether to stream Codex stdout/stderr
    # @param stdout [IO, nil] stream target for stdout
    # @param stderr [IO, nil] stream target for stderr
    # @param observer [#call, nil] optional structured event observer
    # @param executor [#call, nil] test seam for command execution
    def initialize(
      command: "codex",
      working_directory: Dir.pwd,
      model: nil,
      sandbox: "workspace-write",
      approval_policy: "never",
      output_last_message: nil,
      extra_args: [],
      stream: false,
      stdout: $stdout,
      stderr: $stderr,
      observer: nil,
      executor: nil
    )
      @model = model
      @sandbox = sandbox
      @approval_policy = approval_policy
      @output_last_message = output_last_message
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

    def call(task)
      super.tap { emit_final_message(task) }
    end

    private

    def command_for(_instruction)
      [command].tap do |args|
        args.push("--ask-for-approval", @approval_policy) if @approval_policy
        args.push("exec", "-C", working_directory, "--sandbox", @sandbox)
        args.push("--model", @model) if @model
        args.push("--output-last-message", @output_last_message) if @output_last_message
        args.concat(extra_args)
        args.push("-")
      end
    end

    def execution_error(result)
      ExecutionError.new(result)
    end

    def emit_final_message(task)
      return unless @output_last_message && File.file?(@output_last_message)

      content = File.read(@output_last_message)
      emit_event("agent.final_message", task, message: content)
    end
  end
end
