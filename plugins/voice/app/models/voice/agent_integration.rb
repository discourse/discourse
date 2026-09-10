# frozen_string_literal: true

module Voice
  class AgentIntegration < ActiveRecord::Base
    self.table_name = "#{Voice.table_name_prefix}agent_integrations"

    ROLE_PARTICIPANT = 0
    ROLE_SPEAKER = 1
    ROLES = { "participant" => ROLE_PARTICIPANT, "speaker" => ROLE_SPEAKER }.freeze

    belongs_to :bot_user, class_name: "User"
    has_many :integration_rooms,
             class_name: "Voice::AgentIntegrationRoom",
             dependent: :delete_all,
             inverse_of: :agent_integration
    has_many :rooms, through: :integration_rooms, source: :room
    has_many :exclusions, class_name: "Voice::AgentExclusion", dependent: :delete_all

    validates :name, presence: true, length: { maximum: 100 }
    validates :bot_user_id, numericality: { less_than: 0 }
    validates :bot_user_id, uniqueness: true
    validates :credential_digest, presence: true
    validates :role, inclusion: { in: ROLES.values }

    def active?
      revoked_at.nil?
    end

    def role_name
      ROLES.key(role)
    end

    def role_name=(name)
      self.role = ROLES.fetch(name.to_s) { raise Discourse::InvalidParameters.new(:role) }
    end

    def excluded_from?(room)
      exclusions.active.where(room_id: room.id).exists?
    end

    def revoke!
      update!(revoked_at: Time.current)
    end

    def restore!
      update!(revoked_at: nil)
    end
  end
end

# == Schema Information
#
# Table name: voice_agent_integrations
#
#  id                :bigint           not null, primary key
#  credential_digest :string           not null
#  name              :string           not null
#  revoked_at        :datetime
#  role              :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  bot_user_id       :bigint           not null
#
# Indexes
#
#  index_voice_agent_integrations_on_bot_user_id        (bot_user_id) UNIQUE
#  index_voice_agent_integrations_on_credential_digest  (credential_digest) UNIQUE
#
