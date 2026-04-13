# frozen_string_literal: true

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

module DiscourseWorkflowsSpecHelper
  extend ActiveSupport::Concern

  included { before { SiteSetting.discourse_workflows_enabled = true } }
end

RSpec.configure { |config| config.include DiscourseWorkflowsSpecHelper }
