# frozen_string_literal: true

module ::Live
  PLUGIN_NAME = "live"
  ROOM_CHANNEL_PREFIX = "/live/rooms"
  ROOM_INDEX_CHANNEL = "/live/rooms/index"

  # Chat::Thread custom field marking a thread as a room's live session
  # thread, so it can be traced back to its room long after the live session
  # pointer in Redis has expired.
  THREAD_ROOM_ID_FIELD = "live_room_id"

  def self.table_name_prefix
    "live_"
  end

  def self.enabled?
    SiteSetting.live_enabled
  end

  # Callers must omit raw errors and payloads, which can contain credentials or content.
  def self.warn(message)
    Rails.logger.warn(message) if SiteSetting.live_verbose_logging
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
  # don't come only from that table (see config/initializers/004-message_bus.rb):
  # logged-in clients carry the logged_in_users pseudo-group and anonymous
  # clients carry anonymous_users, so targeting the allowed groups reaches
  # exactly the visitors who may see public rooms — anonymous ones included,
  # when they are admitted.
  def self.public_room_message_bus_targets
    { group_ids: SiteSetting.live_allowed_groups_map }
  end
end

require_relative "live/engine"
require_relative "live/guardian_extension"
require_relative "live/ice_config"
require_relative "live/livekit"
require_relative "live/livekit/twirp"
require_relative "live/livekit/egress_client"
require_relative "live/livekit/health_check"
require_relative "live/livekit/room_service_client"
require_relative "live/livekit/agent_dispatch_client"
require_relative "live/livekit/cloud_agent_client"
require_relative "live/livekit/webhook_verifier"
require_relative "live/inline_onebox_handler"
require_relative "live/media_entitlements"
require_relative "live/onebox_handler"
require_relative "live/reactions"
require_relative "live/room_hashtag_data_source"
require_relative "live/user_status_manager"
require_relative "../app/services/live/agent_manager"
