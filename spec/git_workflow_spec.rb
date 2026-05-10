# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe EminenceGrise::GitWorkflow do
  GitWorkflowStatus = Struct.new(:success?)

  def git!(working_directory, *args)
    stdout, stderr, status = Open3.capture3("git", *args, chdir: working_directory)
    raise "git #{args.join(' ')} failed: #{stderr}#{stdout}" unless status.success?

    stdout
  end

  def initialize_repo
    git!(repo, "init")
    git!(repo, "config", "user.email", "agent@example.test")
    git!(repo, "config", "user.name", "Agent")
    File.write(File.join(repo, "README.md"), "# Sandbox\n")
    git!(repo, "add", "README.md")
    git!(repo, "commit", "-m", "initial commit")
  end

  let(:repo) { Dir.mktmpdir("eminence-grise-git-workflow-") }
  let(:task) do
    EminenceGrise::Task.new(
      id: "sandbox-readme",
      title: "Improve README",
      metadata: {
        working_directory: repo,
        branch: "biximilien/docs/sandbox-readme",
        commit_message: "docs: improve sandbox readme"
      }
    )
  end

  before do
    initialize_repo
  end

  after do
    FileUtils.rm_rf(repo)
  end

  it "creates a missing nested branch from current HEAD" do
    described_class.new.before_task(task)

    expect(git!(repo, "branch", "--show-current").strip).to eq("biximilien/docs/sandbox-readme")
  end

  it "checks out an existing branch" do
    git!(repo, "branch", "biximilien/docs/sandbox-readme")

    described_class.new.before_task(task)

    expect(git!(repo, "branch", "--show-current").strip).to eq("biximilien/docs/sandbox-readme")
  end

  it "fails when the target repository is dirty before workflow starts" do
    File.write(File.join(repo, "README.md"), "# Dirty\n")

    expect do
      described_class.new.before_task(task)
    end.to raise_error(described_class::Error, /working tree is dirty before branch setup/)
  end

  it "commits all changes after a successful task" do
    workflow = described_class.new
    workflow.before_task(task)
    File.write(File.join(repo, "README.md"), "# Better Sandbox\n")
    File.write(File.join(repo, "notes.md"), "agent notes\n")

    workflow.after_task(task, "done")

    expect(git!(repo, "status", "--porcelain")).to eq("")
    expect(git!(repo, "log", "-1", "--pretty=%s").strip).to eq("docs: improve sandbox readme")
    expect(git!(repo, "ls-files")).to include("notes.md")
  end

  it "uses an AgentResult commit message before task metadata" do
    workflow = described_class.new
    workflow.before_task(task)
    File.write(File.join(repo, "README.md"), "# Better Sandbox\n")
    result = EminenceGrise::AgentResult.complete(metadata: { commit_message: "docs: agent supplied message" })

    workflow.after_task(task, result)

    expect(git!(repo, "log", "-1", "--pretty=%s").strip).to eq("docs: agent supplied message")
  end

  it "completes without a commit when there are no changes" do
    workflow = described_class.new
    workflow.before_task(task)
    original_head = git!(repo, "rev-parse", "HEAD").strip

    workflow.after_task(task, "done")

    expect(git!(repo, "rev-parse", "HEAD").strip).to eq(original_head)
  end

  it "fails when changes exist but no commit message is available" do
    task_without_message = EminenceGrise::Task.new(
      id: "sandbox-readme",
      title: "Improve README",
      metadata: {
        working_directory: repo,
        branch: "biximilien/docs/sandbox-readme"
      }
    )
    workflow = described_class.new
    workflow.before_task(task_without_message)
    File.write(File.join(repo, "README.md"), "# Better Sandbox\n")

    expect do
      workflow.after_task(task_without_message, "done")
    end.to raise_error(described_class::Error, /commit_message metadata is required/)
  end

  it "raises concise errors when git commands fail" do
    executor = lambda do |_command, working_directory:|
      expect(working_directory).to eq(repo)
      ["", "fatal: bad revision", GitWorkflowStatus.new(false)]
    end

    expect do
      described_class.new(executor: executor).before_task(task)
    end.to raise_error(described_class::Error, /not a git repository|git .* failed: fatal: bad revision/)
  end
end
