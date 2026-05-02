# frozen_string_literal: true

require "json"
require "open3"

module EminenceGrise
  class CodexAgent
    Result = Struct.new(:task, :instruction, :stdout, :stderr, :status, keyword_init: true)

    class ExecutionError < StandardError
      attr_reader :result

      def initialize(result)
        @result = result
        super("codex exec failed for #{result.task.id}: #{result.stderr}")
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
      result = Result.new(task: task, instruction: instruction, stdout: stdout, stderr: stderr, status: status)

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
  end
end
