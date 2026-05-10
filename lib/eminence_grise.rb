# frozen_string_literal: true

# Top-level namespace for the Eminence Grise framework.
module EminenceGrise; end

require_relative "eminence_grise/agents/agent"
require_relative "eminence_grise/agents/registry"
require_relative "eminence_grise/agents/result"
require_relative "eminence_grise/agents/cli_agent"
require_relative "eminence_grise/agents/codex_agent"
require_relative "eminence_grise/agents/claude_code_agent"
require_relative "eminence_grise/agents/open_code_agent"
require_relative "eminence_grise/agents/router_agent"
require_relative "eminence_grise/daemon"
require_relative "eminence_grise/git_workflow"
require_relative "eminence_grise/jobs/active_job"
require_relative "eminence_grise/jobs/adapter"
require_relative "eminence_grise/jobs/sidekiq"
require_relative "eminence_grise/logging"
require_relative "eminence_grise/memory_queue"
require_relative "eminence_grise/process_runner"
require_relative "eminence_grise/result_handler"
require_relative "eminence_grise/runner"
require_relative "eminence_grise/task"
require_relative "eminence_grise/task_payload"
require_relative "eminence_grise/version"
