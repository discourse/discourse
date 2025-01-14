# frozen_string_literal: true

RSpec.describe "Chat New Message from params", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:public_channel) { Fabricate(:chat_channel) }
  fab!(:user_1_channel) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }
  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    public_channel.add(current_user)
    sign_in(current_user)
  end

  def group_slug(users)
    users.pluck(:username).permutation.map { |u| u.join("-") }.join("|")
  end

  context "with a single user" do
    it "redirects to existing chat channel" do
      chat_page.visit_new_message(user_1)

      expect(page).to have_current_path("/chat/c/#{user_1.username}/#{user_1_channel.id}")
    end

    it "creates a dm channel and redirects if none exists" do
      chat_page.visit_new_message(user_2)

      expect(page).to have_css(".chat-channel-name__label", text: user_2.username)
      expect(page).to have_current_path("/chat/c/#{user_2.username}/#{Chat::Channel.last.id}")
    end

    it "redirects to chat channel if recipients param is missing" do
      visit("/chat/new-message")

      expect(page).to have_no_current_path("/chat/new-message")
    end
  end

  context "with multiple users" do
    fab!(:group_dm) do
      Fabricate(:direct_message_channel, users: [current_user, user_1, user_2], group: true)
    end
    fab!(:user_3) { Fabricate(:user) }

    it "loads existing dm channel when one exists" do
      expect { chat_page.visit_new_message([user_1, user_2]) }.not_to change { Chat::Channel.count }

      expect(page).to have_current_path(
        %r{/chat/c/(#{group_slug([user_1, user_2])})/#{group_dm.id}},
      )
    end

    it "creates a dm channel when none exists" do
      expect { chat_page.visit_new_message([user_1, user_3]) }.to change { Chat::Channel.count }.by(
        1,
      )

      expect(page).to have_current_path(
        %r{/chat/c/#{group_slug([user_1, user_3])}/#{Chat::Channel.last.id}},
      )
    end

    context "when user has chat disabled" do
      before { user_3.user_option.update!(chat_enabled: false) }

      it "loads channel without the chat disabled user" do
        expect { chat_page.visit_new_message([user_1, user_3]) }.not_to change {
          Chat::Channel.count
        }

        expect(page).to have_current_path("/chat/c/#{user_1.username}/#{user_1_channel.id}")
      end
    end
  end
end
