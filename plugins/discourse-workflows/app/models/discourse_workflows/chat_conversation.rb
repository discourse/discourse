# frozen_string_literal: true

module DiscourseWorkflows
  class ChatConversation < ActiveRecord::Base
    TRIGGER_TYPE = "trigger:workflow_chat"

    self.table_name = "discourse_workflows_chat_conversations"

    belongs_to :channel, class_name: "Chat::Channel"
    belongs_to :user
    belongs_to :bot_user, class_name: "User"

    def self.chat_available?
      defined?(::Chat::Channel) && defined?(SiteSetting.chat_enabled) && SiteSetting.chat_enabled
    end

    def self.bots
      User.where(id: ...0, active: true).not_suspended
    end

    # The trigger `user` may chat with. A draft is for users who can manage workflows, a
    # published trigger for members of one of its allowed groups.
    def self.trigger_for(user, workflow_id:, node_id:, draft:)
      trigger =
        PublishedTrigger.find(
          type: TRIGGER_TYPE,
          workflow_id:,
          node_id:,
          draft:,
          guardian: user.guardian,
        )
      return trigger if trigger.nil? || trigger.draft?

      group_ids =
        Array(trigger.parameters["group_ids"]).filter_map { |id| Integer(id, exception: false) }
      trigger if user.in_any_groups?(group_ids)
    end

    def trigger
      self.class.trigger_for(user, workflow_id:, node_id: trigger_node_id, draft:)
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_chat_conversations
#
#  id              :bigint           not null, primary key
#  draft           :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  bot_user_id     :bigint           not null
#  channel_id      :bigint           not null
#  trigger_node_id :string(100)      not null
#  user_id         :bigint           not null
#  workflow_id     :bigint           not null
#
# Indexes
#
#  index_discourse_workflows_chat_conversations_on_channel_id  (channel_id) UNIQUE
#
