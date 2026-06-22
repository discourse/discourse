# frozen_string_literal: true

require_relative "../discourse_workflows/dev_populator"

namespace :workflows do
  desc "Creates example Discourse workflows"
  task populate: ["db:load_config"] do
    DiscourseWorkflows::DevPopulator.populate!
  end
end
