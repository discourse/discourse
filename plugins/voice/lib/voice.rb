# frozen_string_literal: true

module ::Voice
  PLUGIN_NAME = "voice"
  ROOM_CHANNEL_PREFIX = "/voice/rooms"
  ROOM_INDEX_CHANNEL = "/voice/rooms/index"

  # Chat::Thread custom field marking a thread as a room's voice session
  # thread, so it can be traced back to its room long after the live session
  # pointer in Redis has expired.
  THREAD_ROOM_ID_FIELD = "voice_room_id"

  def self.table_name_prefix
    "voice_"
  end

  def self.enabled?
    SiteSetting.voice_enabled
  end

  def self.room_channel(room_id)
    "#{ROOM_CHANNEL_PREFIX}/#{room_id}"
  end

  def self.room_chat_channel(room_id)
    "#{ROOM_CHANNEL_PREFIX}/#{room_id}/chat"
  end

  def self.room_index_channel
    ROOM_INDEX_CHANNEL
  end

  # Pseudo-groups have no group_users rows, but a client's message-bus groups
  # don't come only from that table: every logged-in client carries the
  # logged_in_users pseudo-group (see config/initializers/004-message_bus.rb),
  # so it can be targeted directly. Only access that includes anonymous
  # visitors (everyone / anonymous_users) publishes untargeted — falling back
  # to untargeted for logged_in_users would hand room directory and
  # participant data to anonymous subscribers on predictable channels.
  def self.public_room_message_bus_targets
    allowed_group_ids = SiteSetting.voice_allowed_groups_map

    anonymous_reachable_group_ids = [
      Group::AUTO_GROUPS[:everyone],
      Group::AUTO_GROUPS[:anonymous_users],
    ]

    return {} if allowed_group_ids.intersect?(anonymous_reachable_group_ids)

    { group_ids: allowed_group_ids }
  end
end

require_relative "voice/engine"
require_relative "voice/guardian_extension"
require_relative "voice/ice_config"
require_relative "voice/livekit"
require_relative "voice/livekit/twirp"
require_relative "voice/livekit/egress_client"
require_relative "voice/livekit/health_check"
require_relative "voice/livekit/room_service_client"
require_relative "voice/livekit/webhook_verifier"
require_relative "voice/room_hashtag_data_source"
require_relative "voice/user_status_manager"
