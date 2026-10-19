# frozen_string_literal: true

require_relative "page_objects/components/voice_sidebar"

describe "Voice rooms in the chat sidebar" do
  let(:chat_rooms_sidebar) do
    PageObjects::Components::VoiceSidebar.new(section_name: "voice-rooms-chat")
  end
  let(:main_rooms_sidebar) { PageObjects::Components::VoiceSidebar.new }
  let(:chat_page) { PageObjects::Pages::Chat.new }

  fab!(:user)
  fab!(:admin)
  fab!(:channel, :category_channel)
  fab!(:room) { Fabricate(:voice_room, name: "Watercooler", creator: admin, public: true) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_mesh_privacy_warning_enabled = false
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    chat_system_bootstrap(user, [channel])
    sign_in(user)
  end

  context "when the chat separate sidebar mode keeps the chat panel on its own" do
    before do
      user.user_option.update!(
        chat_separate_sidebar_mode: UserOption.chat_separate_sidebar_modes[:always],
      )
    end

    it "shows the voice rooms in the full-screen chat sidebar" do
      chat_page.visit_channel(channel)

      expect(chat_rooms_sidebar).to be_visible
      expect(chat_rooms_sidebar).to have_room(room.name)
    end
  end

  context "when the chat separate sidebar mode is combined" do
    before do
      user.user_option.update!(
        chat_separate_sidebar_mode: UserOption.chat_separate_sidebar_modes[:never],
      )
    end

    it "shows the rooms once via the main panel and not as a duplicate chat section" do
      chat_page.visit_channel(channel)

      expect(main_rooms_sidebar).to be_visible
      expect(main_rooms_sidebar).to have_room(room.name)
      expect(chat_rooms_sidebar).to be_not_visible
    end
  end
end
