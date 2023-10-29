# frozen_string_literal: true

RSpec.describe "Channel - Info - Members page", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "as unauthorized user" do
    before { SiteSetting.chat_allowed_groups = Fabricate(:group).id }

    it "can't see channel members" do
      chat_page.visit_channel_members(channel_1)

      expect(page).to have_current_path("/latest")
    end
  end

  context "as authorized user" do
    context "with no members" do
      it "redirects to settings page" do
        chat_page.visit_channel_members(channel_1)

        expect(page).to have_current_path("/chat/c/#{channel_1.slug}/#{channel_1.id}/info/settings")
      end
    end

    context "with members" do
      before do
        channel_1.add(current_user)
        channel_1.add(Fabricate(:user, username: "cat"))
        98.times { channel_1.add(Fabricate(:user)) }
        Jobs.run_immediately!
        channel_1.update!(user_count_stale: true)
        Jobs::Chat::UpdateChannelUserCount.new.execute(chat_channel_id: channel_1.id)
      end

      xit "shows all members" do
        chat_page.visit_channel_members(channel_1)

        expect(page).to have_selector(".chat-channel-members__list-item", count: 60)

        scroll_to(find(".chat-channel-members__list-item:nth-child(60)"))

        expect(page).to have_selector(".chat-channel-members__list-item", count: 100)

        scroll_to(find(".chat-channel-members__list-item:nth-child(100)"))

        expect(page).to have_selector(".chat-channel-members__list-item", count: 100)
      end

      context "with filter" do
        it "filters members" do
          chat_page.visit_channel_members(channel_1)
          find(".chat-channel-members__filter").fill_in(with: "cat")

          expect(page).to have_selector(".chat-channel-members__list-item", count: 1, text: "cat")
        end
      end
    end
  end
end
