# frozen_string_literal: true

module Voice
  class AgentExclusion < ActiveRecord::Base
    self.table_name = "#{Voice.table_name_prefix}agent_exclusions"

    belongs_to :agent_integration, class_name: "Voice::AgentIntegration"
    belongs_to :room, class_name: "Voice::Room"

    scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  end
end

# == Schema Information
#
# Table name: voice_agent_exclusions
#
#  id                   :bigint           not null, primary key
#  expires_at           :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  agent_integration_id :bigint           not null
#  room_id              :bigint           not null
#
# Indexes
#
#  idx_voice_agent_exclusions_unique           (agent_integration_id,room_id) UNIQUE
#  index_voice_agent_exclusions_on_expires_at  (expires_at)
#
