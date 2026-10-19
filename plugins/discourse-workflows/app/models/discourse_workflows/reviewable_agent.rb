# frozen_string_literal: true

module DiscourseWorkflows
  class ReviewableAgent < ActiveRecord::Base
    self.table_name = "discourse_workflows_reviewable_agents"

    belongs_to :reviewable, class_name: "::Reviewable"
  end
end

# == Schema Information
#
# Table name: discourse_workflows_reviewable_agents
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  ai_agent_id   :bigint           not null
#  reviewable_id :bigint           not null
#
# Indexes
#
#  idx_dwf_reviewable_agents_on_agent_reviewable  (ai_agent_id,reviewable_id)
#  idx_dwf_reviewable_agents_on_reviewable_agent  (reviewable_id,ai_agent_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (reviewable_id => reviewables.id) ON DELETE => cascade
#
