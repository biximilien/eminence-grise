# frozen_string_literal: true

require_relative "cli_agent"

module EminenceGrise
  class CodexAgent < CliAgent
    Result = CliAgent::Result

    class ExecutionError < CliAgent::ExecutionError
      def initialize(result)
        super(result, command_name: "codex exec")
      end
    end

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
        executor: executor
      )
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
  end
end
