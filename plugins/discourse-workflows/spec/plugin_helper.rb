# frozen_string_literal: true

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

module DiscourseWorkflowsSpecHelper
  extend ActiveSupport::Concern

  included do
    before do
      SiteSetting.discourse_workflows_enabled = true
      SiteSetting.external_system_avatars_url = "https://example.com/avatar/{username}.png"
      DiscourseWorkflows::Registry.reset_indexes!
      Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear
      Jobs::DiscourseWorkflows::ExecuteManualWorkflow.jobs.clear
      Jobs::DiscourseWorkflows::ResumeWebhookWaiting.jobs.clear
      Jobs::DiscourseWorkflows::ResumeWaitingExecution.jobs.clear
    end
  end
end

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/plugins/discourse-workflows/spec/}) do |metadata|
    metadata[:discourse_workflows] = true
  end

  config.include DiscourseWorkflowsSpecHelper, discourse_workflows: true
end
