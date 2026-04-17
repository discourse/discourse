# frozen_string_literal: true

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

module DiscourseWorkflowsSpecHelper
  extend ActiveSupport::Concern

  included do
    before do
      SiteSetting.discourse_workflows_enabled = true
      Jobs::DiscourseWorkflows::ExecuteSecondsSchedule.jobs.clear
      Jobs::DiscourseWorkflows::ResumeWaitingExecution.jobs.clear
    end
  end
end

RSpec.configure { |config| config.include DiscourseWorkflowsSpecHelper }
