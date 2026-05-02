# frozen_string_literal: true

require_relative "cli_agent"

module EminenceGrise
  class OpenCodeAgent < CliAgent
    Result = CliAgent::Result

    class ExecutionError < CliAgent::ExecutionError
      def initialize(result)
        super(result, command_name: "opencode")
      end
    end

    def initialize(
      command: "opencode",
      working_directory: Dir.pwd,
      model: nil,
      agent: nil,
      output_format: nil,
      extra_args: [],
      executor: nil
    )
      @model = model
      @agent = agent
      @output_format = output_format
      super(command: command, working_directory: working_directory, extra_args: extra_args, executor: executor)
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

    def execution_error(result)
      ExecutionError.new(result)
    end
  end
end
