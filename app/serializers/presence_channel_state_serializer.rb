# frozen_string_literal: true

class PresenceChannelStateSerializer < ApplicationSerializer
  attributes :count, :last_message_id
  has_many :users, serializer: BasicUserSerializer, embed: :objects

  def last_message_id
    object.message_bus_last_id
  end

  def include_users?
    !users.nil?
  end
end
