# frozen_string_literal: true

require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260220154336_add_cooked_description_to_voice_rooms"
require_relative "../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"
require_relative "../../../db/migrate/20260630183841_add_chat_settings_to_voice_rooms"

RSpec.describe Voice::RoomHashtagDataSource do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :cooked_description)
        AddCookedDescriptionToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :room_type)
        AddRoomTypeToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :video_enabled)
        AddVideoEnabledToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :chat_channel_id)
        AddChatSettingsToVoiceRooms.new.change
      end
      Voice::Room.reset_column_information
    end

    SiteSetting.voice_enabled = true
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
    # The default create-rooms groups include TL2, which makes any TL2 user a
    # global room manager who can see every room — raise the bar so the
    # visibility assertions below actually exercise the membership checks.
    SiteSetting.voice_create_room_allowed_groups = Group::AUTO_GROUPS[:trust_level_4].to_s
  end

  fab!(:creator) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:room) do
    Fabricate(:voice_room, name: "General", description: "Come hang out", public: true, creator:)
  end
  fab!(:private_room) { Fabricate(:voice_room, name: "Secret Sessions", creator:) }
  fab!(:stage_room) do
    Fabricate(
      :voice_room,
      name: "Town Hall",
      public: true,
      room_type: Voice::Room::ROOM_TYPE_STAGE,
      creator:,
    )
  end

  let(:guardian) { Guardian.new(user) }

  def hashtag_hash(room)
    {
      relative_url: "/voice/r/#{room.slug}",
      text: room.name,
      description: room.description,
      icon: room.stage? ? "podcast" : "microphone-lines",
      style_type: "icon",
      emoji: nil,
      colors: nil,
      type: "room",
      ref: nil,
      slug: room.slug,
      id: room.id,
    }
  end

  describe "#enabled?" do
    it "follows the voice_enabled setting" do
      expect(described_class.enabled?).to eq(true)
      SiteSetting.voice_enabled = false
      expect(described_class.enabled?).to eq(false)
    end
  end

  describe "#lookup" do
    it "finds a room by slug" do
      expect(described_class.lookup(guardian, ["general"]).map(&:to_h)).to eq([hashtag_hash(room)])
    end

    it "matches stored slugs case-insensitively" do
      room.update_columns(slug: "GeNeRaL")
      expect(described_class.lookup(guardian, ["general"]).map(&:id)).to eq([room.id])
    end

    it "can return multiple rooms" do
      expect(described_class.lookup(guardian, %w[general town-hall]).map(&:slug)).to eq(
        %w[general town-hall],
      )
    end

    it "uses the podcast icon for stage rooms" do
      expect(described_class.lookup(guardian, ["town-hall"]).first.to_h).to eq(
        hashtag_hash(stage_room),
      )
    end

    it "uses the base icon for private rooms" do
      expect(described_class.lookup(Guardian.new(creator), ["secret-sessions"]).first.icon).to eq(
        "microphone-lines",
      )

      private_room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)
      expect(described_class.lookup(Guardian.new(creator), ["secret-sessions"]).first.icon).to eq(
        "podcast",
      )
    end

    it "does not return a private room the user is not a member of" do
      expect(described_class.lookup(guardian, ["secret-sessions"])).to be_empty
    end

    it "returns a private room to its members" do
      private_room.room_memberships.create!(user: user)
      expect(described_class.lookup(guardian, ["secret-sessions"]).map(&:slug)).to eq(
        ["secret-sessions"],
      )
    end

    it "returns a private room to its creator" do
      expect(described_class.lookup(Guardian.new(creator), ["secret-sessions"]).map(&:slug)).to eq(
        ["secret-sessions"],
      )
    end

    it "never returns ephemeral rooms" do
      ephemeral = Fabricate(:voice_ephemeral_room, name: "General Call", public: true, creator:)

      expect(described_class.lookup(guardian, [ephemeral.slug])).to be_empty
      expect(described_class.search(guardian, "general call", 5)).to be_empty
    end

    it "returns nothing for users outside voice_allowed_groups" do
      SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
      expect(described_class.lookup(guardian, ["general"])).to be_empty
    end

    it "returns public rooms to anonymous users when anonymous visitors are admitted" do
      expect(described_class.lookup(Guardian.new, ["general"])).to be_empty

      SiteSetting.voice_allowed_groups =
        "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
      expect(described_class.lookup(Guardian.new, %w[general secret-sessions]).map(&:slug)).to eq(
        ["general"],
      )
    end
  end

  describe "#search" do
    it "finds a room by name" do
      expect(described_class.search(guardian, "gener", 10).map(&:to_h)).to eq([hashtag_hash(room)])
    end

    it "finds a room by slug and matches anywhere in the term" do
      expect(described_class.search(guardian, "hall", 10).map(&:slug)).to eq(["town-hall"])
    end

    it "only matches the start of the term with the starts_with condition" do
      starts_with = HashtagAutocompleteService.search_conditions[:starts_with]
      expect(described_class.search(guardian, "hall", 10, starts_with)).to be_empty
      expect(described_class.search(guardian, "town", 10, starts_with).map(&:slug)).to eq(
        ["town-hall"],
      )
    end

    it "does not return private rooms the user cannot see" do
      expect(described_class.search(guardian, "secret", 10)).to be_empty
      expect(described_class.search(Guardian.new(creator), "secret", 10).map(&:slug)).to eq(
        ["secret-sessions"],
      )
    end

    it "respects the limit and keeps name ordering when truncating" do
      expect(described_class.search(Guardian.new(creator), "e", 1).map(&:slug)).to eq(["general"])
    end

    it "treats SQL wildcard characters in the term literally" do
      expect(described_class.search(guardian, "%", 10)).to be_empty
      expect(described_class.search(guardian, "gen_ral", 10)).to be_empty
    end
  end

  describe "#search_without_term" do
    it "returns visible rooms ordered by name" do
      expect(described_class.search_without_term(guardian, 10).map(&:slug)).to eq(
        %w[general town-hall],
      )
      expect(described_class.search_without_term(Guardian.new(creator), 10).map(&:slug)).to eq(
        %w[general secret-sessions town-hall],
      )
    end
  end

  describe "#find_by_ids" do
    it "returns only visible rooms among the ids" do
      expect(described_class.find_by_ids(guardian, [room.id, private_room.id]).map(&:id)).to eq(
        [room.id],
      )
    end
  end

  describe "#search_sort" do
    it "orders results by text" do
      results = [stage_room, room].map { |r| described_class.room_to_hashtag_item(r) }
      expect(described_class.search_sort(results, "").map(&:slug)).to eq(%w[general town-hall])
    end
  end

  describe "cooking" do
    it "cooks a room hashtag into a link for a user who can see the room" do
      cooked = PrettyText.cook("#general::room", user_id: user.id)
      link = Nokogiri::HTML5.fragment(cooked).css("a.hashtag-cooked").first

      expect(link["href"]).to eq("/voice/r/general")
      expect(link["data-type"]).to eq("room")
      expect(link["data-slug"]).to eq("general")
      expect(link["data-id"]).to eq(room.id.to_s)
      expect(link["data-icon"]).to eq("microphone-lines")
    end

    it "leaves the hashtag raw for a user who cannot see the room" do
      cooked = PrettyText.cook("#secret-sessions::room", user_id: user.id)

      expect(Nokogiri::HTML5.fragment(cooked).css("a.hashtag-cooked")).to be_empty
      expect(cooked).to include("hashtag-raw")
    end
  end

  describe "chat hashtag configuration snapshot" do
    it "tracks the voice_enabled setting at runtime" do
      skip "chat plugin not installed" unless defined?(::Chat)

      SiteSetting.voice_enabled = false
      expect(
        Site.markdown_additional_options.dig("chat", :hashtag_configurations)["chat-composer"],
      ).not_to include("room")

      SiteSetting.voice_enabled = true
      expect(
        Site.markdown_additional_options.dig("chat", :hashtag_configurations)["chat-composer"],
      ).to include("room")
    end
  end
end
