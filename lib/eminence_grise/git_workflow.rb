# frozen_string_literal: true

require "open3"

require_relative "agents/result"
require_relative "logging"

module EminenceGrise
  # Local Git branch and commit workflow for agent tasks.
  class GitWorkflow
    # Raised when Git workflow setup or commit work fails.
    class Error < StandardError; end

    # @param logger [Logger, #puts, nil] optional logger
    # @param executor [#call, nil] injectable command executor for tests
    def initialize(logger: nil, executor: nil)
      @logger = Logging.coerce(logger)
      @executor = executor || method(:capture)
    end

    # Prepare a task repository before agent execution.
    #
    # @param task [Task]
    # @return [void]
    def before_task(task)
      working_directory = required_metadata(task, :working_directory)
      branch = required_metadata(task, :branch)

      verify_repository!(working_directory)
      ensure_clean!(working_directory, "before branch setup")

      if branch_exists?(working_directory, branch)
        git!(working_directory, "checkout", branch)
        @logger.info("git branch checked out branch=#{branch.inspect} working_directory=#{working_directory.inspect}")
      else
        git!(working_directory, "checkout", "-b", branch)
        @logger.info("git branch created branch=#{branch.inspect} working_directory=#{working_directory.inspect}")
      end

      ensure_clean!(working_directory, "after branch setup")
    end

    # Commit task repository changes after successful agent execution.
    #
    # @param task [Task]
    # @param result [Object]
    # @return [void]
    def after_task(task, result)
      working_directory = required_metadata(task, :working_directory)

      git!(working_directory, "add", "--all")
      unless staged_changes?(working_directory)
        @logger.info("git commit skipped no changes working_directory=#{working_directory.inspect}")
        return
      end

      message = commit_message_for(task, result)
      raise Error, "commit_message metadata is required when task produces git changes" unless message

      git!(working_directory, "commit", "-m", message)
      @logger.info("git commit created working_directory=#{working_directory.inspect} message=#{message.inspect}")
    end

    private

    def verify_repository!(working_directory)
      stdout, _stderr, status = git(working_directory, "rev-parse", "--is-inside-work-tree")
      return if status.success? && stdout.strip == "true"

      raise Error, "working_directory is not a git repository: #{working_directory.inspect}"
    end

    def ensure_clean!(working_directory, context)
      stdout, _stderr, _status = git!(working_directory, "status", "--porcelain")
      return if stdout.empty?

      raise Error, "git working tree is dirty #{context} in #{working_directory.inspect}"
    end

    def branch_exists?(working_directory, branch)
      _stdout, _stderr, status = git(working_directory, "show-ref", "--verify", "--quiet", "refs/heads/#{branch}")
      status.success?
    end

    def staged_changes?(working_directory)
      _stdout, _stderr, status = git(working_directory, "diff", "--cached", "--quiet")
      !status.success?
    end

    def commit_message_for(task, result)
      if result.is_a?(AgentResult)
        value = metadata_value(result.metadata, :commit_message)
        return value if present?(value)
      end

      value = task.metadata_value(:commit_message)
      return value if present?(value)

      nil
    end

    def required_metadata(task, key)
      value = task.metadata_value(key)
      raise Error, "#{key} metadata is required for git workflow" unless present?(value)

      value
    end

    def present?(value)
      value && !(value.respond_to?(:empty?) && value.empty?)
    end

    def metadata_value(metadata, key)
      return metadata[key] if metadata.key?(key)

      alternate_key = key.is_a?(Symbol) ? key.to_s : key.to_sym
      metadata[alternate_key]
    end

    def git!(working_directory, *args)
      stdout, stderr, status = git(working_directory, *args)
      raise Error, failure_message(args, stdout, stderr) unless status.success?

      [stdout, stderr, status]
    end

    def git(working_directory, *args)
      @executor.call(["git", *args], working_directory: working_directory)
    rescue SystemCallError => error
      raise Error, "could not start git: #{error.message}"
    end

    def capture(command, working_directory:)
      Open3.capture3(*command, chdir: working_directory)
    end

    def failure_message(args, stdout, stderr)
      detail = [stderr, stdout].join("\n").lines.map(&:strip).reject(&:empty?).first(3).join(" | ")
      detail = "command exited unsuccessfully" if detail.empty?
      "git #{args.join(' ')} failed: #{detail}"
    end
  end
end
