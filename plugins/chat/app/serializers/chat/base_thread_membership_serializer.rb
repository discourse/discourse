# frozen_string_literal: true

module Chat
  class BaseThreadMembershipSerializer < ApplicationSerializer
    attributes :notification_level, :thread_id, :last_read_message_id
  end
end
