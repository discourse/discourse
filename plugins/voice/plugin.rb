# frozen_string_literal: true

# name: voice
# about: Voice chat rooms powered by WebRTC inside Discourse
# version: 0.1
# authors: Discourse Contributors
# url: https://github.com/discourse/discourse/tree/main/plugins/voice

require "discourse_voice_assets"

# The large media assets (wasm engines, ML models, vendored SDK bundles) ship
# in the discourse_voice_assets gem under stable filenames. Link its vendor
# tree into the plugin's public dir — gitignored, rebuilt on every boot — at a
# gem-version-stamped path: /plugins/ assets are cached long-term as
# immutable, so the versioned URL is what busts caches on a gem bump. The
# client learns the current base path from the site serializer.
voice_javascripts_dir = File.join(__dir__, "public", "javascripts")
FileUtils.mkdir_p(voice_javascripts_dir)
Dir
  .children(voice_javascripts_dir)
  .each do |entry|
    if entry != DiscourseVoiceAssets::VERSION
      FileUtils.rm_rf(File.join(voice_javascripts_dir, entry))
    end
  end
Discourse::Utils.atomic_ln_s(
  DiscourseVoiceAssets.vendor_path,
  File.join(voice_javascripts_dir, DiscourseVoiceAssets::VERSION),
)

enabled_site_setting :voice_enabled

register_svg_icon "microphone-lines"
register_svg_icon "lock"
register_svg_icon "phone"
register_svg_icon "waveform"
register_svg_icon "ear-listen"
register_svg_icon "volume-high"
register_svg_icon "microphone"
register_svg_icon "microphone-slash"
register_svg_icon "volume-xmark"
register_svg_icon "walkie-talkie"
register_svg_icon "discourse-sparkles"
register_svg_icon "keyboard"
register_svg_icon "phone-slash"
register_svg_icon "phone-volume"
register_svg_icon "podcast"
register_svg_icon "handshake"
register_svg_icon "users"
register_svg_icon "user-group"
register_svg_icon "compass"
register_svg_icon "calendar"
register_svg_icon "house"
register_svg_icon "bullhorn"
register_svg_icon "star"
register_svg_icon "moon"
register_svg_icon "sun"
register_svg_icon "people-group"
register_svg_icon "calendar-week"
register_svg_icon "trophy"
register_svg_icon "clock"
register_svg_icon "video"
register_svg_icon "video-slash"
register_svg_icon "display"
register_svg_icon "expand"
register_svg_icon "compress"
register_svg_icon "far-comment"
register_svg_icon "comment-slash"
register_svg_icon "paper-plane"
register_svg_icon "xmark"
register_svg_icon "up-right-from-square"
register_svg_icon "person-chalkboard"
register_svg_icon "table-cells"
register_svg_icon "circle-check"
register_svg_icon "circle-xmark"
register_svg_icon "triangle-exclamation"
register_svg_icon "hand"
register_svg_icon "check"
register_svg_icon "record-vinyl"
register_svg_icon "flag"
register_svg_icon "thumbs-up"
register_svg_icon "thumbs-down"
register_svg_icon "ban"
register_svg_icon "user-plus"
register_svg_icon "circle-nodes"
register_svg_icon "magnet"
register_svg_icon "copy"
register_svg_icon "closed-captioning"
register_svg_icon "stop"
register_svg_icon "far-file-lines"
register_asset "stylesheets/common/voice.scss"
register_asset "stylesheets/common/voice-room-page.scss"
register_asset "stylesheets/common/voice-chat.scss"
register_asset "stylesheets/common/voice-admin.scss", :admin

add_admin_route "voice.admin.title", "voice", use_new_show_route: true

require_relative "lib/voice"

after_initialize do
  SeedFu.fixture_paths << Rails.root.join("plugins/voice/db/fixtures").to_s

  require_relative "lib/voice/user_extension"

  Discourse::Application.routes.append { mount ::Voice::Engine, at: "/voice" }

  Guardian.prepend Voice::GuardianExtension

  register_reviewable_type ReviewableVoiceUser

  # Chat snapshots the hashtag orderings into Site.markdown_additional_options
  # at its own after_initialize, which runs before this one (plugins load
  # alphabetically) — refresh it so chat transcripts quoted inside posts can
  # cook room hashtags too. The snapshot also bakes in each source's enabled?
  # state, so it must be refreshed again when voice_enabled toggles.
  def self.refresh_chat_hashtag_configurations
    return unless defined?(::Chat) && Site.markdown_additional_options["chat"]

    Site.markdown_additional_options["chat"][
      :hashtag_configurations
    ] = HashtagAutocompleteService.contexts_with_ordered_types
  end

  # Rooms rank below chat channels (200) but above categories (100) in the
  # chat composer, and below everything (category 100, tag 50, channel 10) in
  # the topic composer, so a bare #slug in a post still means the category.
  register_hashtag_data_source(Voice::RoomHashtagDataSource)
  register_hashtag_type_priority_for_context("room", "chat-composer", 150)
  register_hashtag_type_priority_for_context("room", "topic-composer", 5)
  refresh_chat_hashtag_configurations

  # Gates the user-card call button: the viewer needs the direct-call
  # permission and the target must be callable by them — voice-room access,
  # not the viewer themselves or a bot, and not screened out by the target's
  # mute, ignore, or personal message preferences.
  add_to_serializer(
    :user_card,
    :voice_can_call,
    include_condition: -> { scope.can_start_voice_call? },
  ) { scope.can_call_voice_user?(object) }

  # Lets the client decide whether to render the rooms sidebar for anonymous
  # visitors without exposing the configured group ids.
  add_to_serializer(:site, :voice_public_access) { scope.voice_public_access? }

  # Base URL for the gem-vendored media assets (see the symlink setup above).
  # Version-stamped so a gem bump busts the immutable /plugins/ caches; the
  # client builds every asset URL from this, so filenames can stay stable.
  add_to_serializer(:site, :voice_assets_path) do
    "/plugins/voice/javascripts/#{DiscourseVoiceAssets::VERSION}"
  end

  # Gates the room-form SFU checkbox only — the client never needs the policy
  # enum itself, and a live room's transport is learned at join, not here.
  add_to_serializer(:site, :voice_livekit_per_room_available) do
    SiteSetting.voice_livekit_room_policy == "per_room" && Voice::Livekit.configured?
  end

  # Gates the room-form media checkbox: with neither capability granted to any
  # group, a room-level media toggle would decide nothing. The per-user rights
  # themselves ride on each room's serialization instead.
  add_to_serializer(:site, :voice_video_available) do
    SiteSetting.voice_video_allowed_groups.present? ||
      SiteSetting.voice_screen_share_allowed_groups.present?
  end

  Voice::DefaultRoomSeeder.ensure! if SiteSetting.voice_enabled?

  # This can't live in the on(:site_setting_changed) handler below: plugin
  # event handlers are skipped while the plugin is disabled, which silently
  # covers the disabling transition itself.
  on_enabled_change do |_old_value, new_value|
    Voice::DefaultRoomSeeder.ensure! if new_value
    clear_all_voice_statuses unless new_value
    refresh_chat_hashtag_configurations
  end

  on(:user_destroyed) do |user|
    # Sessions are analytics history and survive user deletion (the stats
    # endpoints tolerate the dangling user_id). Rooms must stay owned, so
    # they move to the system user; the roster and per-pair contact rows are
    # meaningless without the user.
    Voice::Room.where(creator_id: user.id).update_all(creator_id: Discourse.system_user.id)
    Voice::RoomMembership.where(user_id: user.id).delete_all
    Voice::CoPresence.where("user_id_1 = :id OR user_id_2 = :id", id: user.id).delete_all
  end

  on(:site_setting_changed) do |name, _old_value, new_value|
    if name.to_sym == :voice_badges_enabled
      if new_value
        Voice::BadgeGranterHooks.enable_all!
      else
        Voice::BadgeGranterHooks.disable_all!
      end
    end

    clear_all_voice_statuses if name.to_sym == :voice_auto_status_enabled && !new_value

    # Surface a bad URL or key pair on the admin status panel within seconds
    # of saving, not at the first user's failed join.
    livekit_settings = %i[
      voice_livekit_url
      voice_livekit_api_key
      voice_livekit_api_secret
      voice_livekit_room_policy
      voice_livekit_mesh_fallback
    ]
    Jobs.enqueue(:voice_livekit_probe) if livekit_settings.include?(name.to_sym)
  end

  def self.clear_all_voice_statuses
    UserStatus
      .where(emoji: [Voice::UserStatusManager::EMOJI, Voice::UserStatusManager::AFK_EMOJI])
      .find_each { |status| User.find_by(id: status.user_id)&.clear_status! }
  end
end
