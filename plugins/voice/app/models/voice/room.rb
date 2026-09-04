# frozen_string_literal: true

module Voice
  class Room < ActiveRecord::Base
    self.table_name = "#{Voice.table_name_prefix}rooms"

    # TODO(02-2027): Remove this line
    self.ignored_columns += %i[chat_thread_title_template]

    ROOM_TYPE_OPEN = 0
    ROOM_TYPE_STAGE = 1
    ROOM_TYPES = { "open" => ROOM_TYPE_OPEN, "stage" => ROOM_TYPE_STAGE }.freeze

    # nil means "no room-level cap" — the site-setting caps still apply.
    QUALITY_PROFILES = { "standard" => 0, "high" => 1, "maximum" => 2 }.freeze

    belongs_to :creator, class_name: "User"
    has_many :room_memberships, class_name: "Voice::RoomMembership", dependent: :destroy
    has_many :members, through: :room_memberships, source: :user
    has_many :recordings, class_name: "Voice::Recording", dependent: :delete_all

    validates :name, presence: true, length: { maximum: 80 }
    validates :slug, presence: true, uniqueness: true
    validates :room_type, inclusion: { in: ROOM_TYPES.values }
    validates :max_participants,
              numericality: {
                only_integer: true,
                allow_nil: true,
                greater_than_or_equal_to: 2,
                less_than_or_equal_to: ->(r) { r.stage? ? 200 : 50 },
              }
    validates :max_quality_profile, inclusion: { in: QUALITY_PROFILES.values }, allow_nil: true
    validates :chat_idle_minutes,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 2,
                less_than_or_equal_to: 1440,
              }
    validate :chat_channel_must_support_threading, if: :chat_channel_id_changed?

    before_validation :ensure_slug
    before_save :cook_description
    after_commit :ensure_creator_membership, on: :create

    scope :public_rooms, -> { where(public: true) }
    scope :persistent, -> { where(ephemeral: false) }
    scope :ephemeral, -> { where(ephemeral: true) }

    class << self
      def visible_to(guardian)
        rooms = persistent
        return rooms.none unless SiteSetting.voice_enabled?

        unless guardian.can_access_voice?
          return guardian.voice_public_access? ? rooms.public_rooms : rooms.none
        end

        return rooms if guardian.is_staff?

        rooms.where(<<~SQL, user_id: guardian.user.id)
            "voice_rooms"."public"
            OR "voice_rooms"."creator_id" = :user_id
            OR EXISTS (
              SELECT 1
              FROM "voice_room_memberships"
              WHERE "voice_room_memberships"."room_id" = "voice_rooms"."id"
                AND "voice_room_memberships"."user_id" = :user_id
            )
          SQL
      end

      # Strict by design: the column is an integer, so letting an unknown name
      # through means AR casts it with to_i and silently produces an open room.
      def room_type_from_name!(name)
        ROOM_TYPES.fetch(name.to_s) { raise Discourse::InvalidParameters.new(:room_type) }
      end
    end

    def open?
      room_type == ROOM_TYPE_OPEN
    end

    def stage?
      room_type == ROOM_TYPE_STAGE
    end

    def room_type_name
      ROOM_TYPES.key(room_type) || "open"
    end

    def max_quality_profile_name
      QUALITY_PROFILES.key(max_quality_profile)
    end

    # The hard presence cap: a room-level limit can lower the site ceiling,
    # never raise it. Enforced atomically when presence is established.
    def effective_max_participants
      [max_participants, SiteSetting.voice_max_room_participants].compact.min
    end

    # Room-level capability only; per-user publish rights are guardian-driven
    # (stage listeners never publish even when this is true).
    def video_allowed?
      SiteSetting.voice_video_enabled && video_enabled
    end

    def membership_for(user)
      return if user.blank?

      if room_memberships.loaded?
        room_memberships.find { |membership| membership.user_id == user.id }
      else
        room_memberships.find_by(user_id: user.id)
      end
    end

    def member?(user)
      membership_for(user).present?
    end

    def moderator?(user)
      membership_for(user)&.moderator? || false
    end

    def moderator_ids
      if room_memberships.loaded?
        room_memberships.select(&:moderator?).map(&:user_id)
      else
        room_memberships.moderator.pluck(:user_id)
      end
    end

    def member_ids
      if room_memberships.loaded?
        room_memberships.map(&:user_id)
      else
        room_memberships.pluck(:user_id)
      end
    end

    def message_bus_targets
      public? ? Voice.public_room_message_bus_targets : { user_ids: member_ids }
    end

    def chat_linked?
      chat_channel_id.present?
    end

    # Memoized (keyed on the current id, so an in-flight reassignment isn't
    # served a stale channel): serialization consults the channel several
    # times per room, which would otherwise be a query each.
    def chat_channel
      return nil unless chat_channel_id && defined?(::Chat)
      if @chat_channel_for_id != chat_channel_id
        @chat_channel_for_id = chat_channel_id
        @chat_channel = ::Chat::Channel.find_by(id: chat_channel_id)
      end
      @chat_channel
    end

    def preload_chat_channel(channel)
      @chat_channel_for_id = chat_channel_id
      @chat_channel = channel
    end

    def reload(...)
      @chat_channel_for_id = @chat_channel = nil
      super
    end

    def chat_idle_seconds
      [chat_idle_minutes || 15, 2].max * 60
    end

    private

    def ensure_slug
      if slug.present?
        # A user-provided slug is normalized rather than trusted verbatim;
        # rejected here (instead of silently regenerating from the name) so
        # the author learns their input was unusable.
        self.slug = Slug.for(slug, "")
        errors.add(:slug, :invalid) if slug.blank?
        return
      end

      return if name.blank?

      # Ephemeral rooms are created programmatically with generic names
      # ("Call", an event title), so a bare Slug.for would collide with the
      # persistent room that already owns that slug.
      self.slug = ephemeral? ? "#{Slug.for(name)}-#{SecureRandom.hex(4)}" : Slug.for(name)
    end

    def cook_description
      self.cooked_description = (PrettyText.cook(description) if description.present?)
    end

    def ensure_creator_membership
      room_memberships.find_or_create_by!(user: creator) do |membership|
        membership.role = Voice::RoomMembership::ROLE_MODERATOR
      end
    end

    # Voice never edits chat channels itself (that would silently change a
    # setting for everyone else using it, on behalf of a user who may not have
    # permission to edit that channel at all) — a channel has to already have
    # threading enabled before it can be linked.
    def chat_channel_must_support_threading
      return if chat_channel_id.blank? || !defined?(::Chat)

      channel = chat_channel
      if channel.nil?
        errors.add(:chat_channel_id, "must reference an existing chat channel")
      elsif !channel.threading_enabled?
        errors.add(:chat_channel_id, "must have threading enabled")
      end
    end
  end
end

# == Schema Information
#
# Table name: voice_rooms
#
#  id                  :bigint           not null, primary key
#  chat_idle_minutes   :integer          default(15), not null
#  cooked_description  :text
#  description         :text
#  ephemeral           :boolean          default(FALSE), not null
#  last_occupied_at    :datetime
#  livekit_enabled     :boolean          default(FALSE), not null
#  max_participants    :integer
#  max_quality_profile :integer
#  name                :string           not null
#  public              :boolean          default(FALSE), not null
#  room_type           :integer          default(0), not null
#  slug                :string           not null
#  video_enabled       :boolean          default(TRUE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chat_channel_id     :bigint
#  creator_id          :bigint           not null
#
# Indexes
#
#  index_voice_rooms_on_chat_channel_id  (chat_channel_id)
#  index_voice_rooms_on_creator_id       (creator_id)
#  index_voice_rooms_on_ephemeral        (id) WHERE ephemeral
#  index_voice_rooms_on_slug             (slug) UNIQUE
#
