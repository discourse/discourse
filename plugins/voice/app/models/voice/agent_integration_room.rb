# frozen_string_literal: true

module Voice
  class AgentIntegrationRoom < ActiveRecord::Base
    self.table_name = "#{Voice.table_name_prefix}agent_integration_rooms"

    belongs_to :agent_integration, class_name: "Voice::AgentIntegration"
    belongs_to :room, class_name: "Voice::Room"
  end
end

# == Schema Information
#
# Table name: voice_agent_integration_rooms
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  agent_integration_id :bigint           not null
#  room_id              :bigint           not null
#
# Indexes
#
#  idx_voice_agent_integration_rooms_unique        (agent_integration_id,room_id) UNIQUE
#  index_voice_agent_integration_rooms_on_room_id  (room_id)
#
