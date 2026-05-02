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
      extra_args: [],
      executor: nil
    )
      @model = model
      @sandbox = sandbox
      @approval_policy = approval_policy
      super(command: command, working_directory: working_directory, extra_args: extra_args, executor: executor)
    end

    private

    def command_for(_instruction)
      [command, "exec", "-C", working_directory, "--sandbox", @sandbox, "--ask-for-approval", @approval_policy].tap do |args|
        args.push("--model", @model) if @model
        args.concat(extra_args)
        args.push("-")
      end
    end

    def execution_error(result)
      ExecutionError.new(result)
    end
  end
end
