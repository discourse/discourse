# frozen_string_literal: true

class UserStatusSerializer < ApplicationSerializer
  attributes :description, :emoji, :ends_at, :message_bus_last_id

  def ends_at
    object.ends_at&.iso8601
  end

  def message_bus_last_id
    MessageBus.last_id("/user-status")
  end
end
