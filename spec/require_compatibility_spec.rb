# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe "require compatibility" do
  def ruby_requires(code)
    Open3.capture3(RbConfig.ruby, "-I./lib", "-e", code)
  end

  it "loads all public constants from the aggregate require" do
    code = <<~RUBY
      require "eminence_grise"
      constants = [
        EminenceGrise::Agent,
        EminenceGrise::CliAgent,
        EminenceGrise::CodexAgent,
        EminenceGrise::ClaudeCodeAgent,
        EminenceGrise::OpenCodeAgent,
        EminenceGrise::AgentRegistry,
        EminenceGrise::AgentResult,
        EminenceGrise::RouterAgent,
        EminenceGrise::ResultHandler,
        EminenceGrise::TaskPayload,
        EminenceGrise::ActiveJob,
        EminenceGrise::Sidekiq
      ]
      exit(constants.all? ? 0 : 1)
    RUBY

    _stdout, stderr, status = ruby_requires(code)

    expect(status).to be_success, stderr
  end

  it "supports the canonical codex agent direct require path" do
    _stdout, stderr, status = ruby_requires(<<~RUBY)
      require "eminence_grise/agents/codex_agent"
      exit(EminenceGrise::CodexAgent && EminenceGrise::CliAgent ? 0 : 1)
    RUBY

    expect(status).to be_success, stderr
  end

  it "supports the canonical agent result direct require path" do
    _stdout, stderr, status = ruby_requires(<<~RUBY)
      require "eminence_grise/agents/result"
      exit(EminenceGrise::AgentResult ? 0 : 1)
    RUBY

    expect(status).to be_success, stderr
  end

  it "supports the canonical result handler direct require path" do
    _stdout, stderr, status = ruby_requires(<<~RUBY)
      require "eminence_grise/result_handler"
      exit(EminenceGrise::ResultHandler ? 0 : 1)
    RUBY

    expect(status).to be_success, stderr
  end

  it "supports the canonical job integration direct require paths" do
    _stdout, stderr, status = ruby_requires(<<~RUBY)
      require "eminence_grise/jobs/active_job"
      require "eminence_grise/jobs/sidekiq"
      exit(EminenceGrise::ActiveJob && EminenceGrise::Sidekiq ? 0 : 1)
    RUBY

    expect(status).to be_success, stderr
  end

  it "supports the canonical task payload direct require path" do
    _stdout, stderr, status = ruby_requires(<<~RUBY)
      require "eminence_grise/task_payload"
      exit(EminenceGrise::TaskPayload ? 0 : 1)
    RUBY

    expect(status).to be_success, stderr
  end
end
