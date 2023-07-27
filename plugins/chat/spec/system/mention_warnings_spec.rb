# frozen_string_literal: true

RSpec.describe "Mentions warnings", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap(current_user, [channel_1])
    sign_in(current_user)
  end

  describe "composing a message with mentions" do
    context "when mentioning a group" do
      context "when the group doesn’t allow mentions" do
        fab!(:admin_mentionable_group) do
          Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:only_admins])
        end

        it "displays a warning" do
          chat_page.visit_channel(channel_1)
          chat_channel_page.type_in_composer("@#{admin_mentionable_group.name} ")

          expect(page).to have_css(".chat-mention-warnings")
          expect(page.find(".chat-mention-warnings-list__simple")).to have_content(
            admin_mentionable_group.name,
          )
        end
      end

      context "when the group allow mentions" do
        fab!(:publicly_mentionable_group) do
          Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone])
        end
        fab!(:user_2) { Fabricate(:user) }

        context "when the group has too many members" do
          before do
            SiteSetting.max_users_notified_per_group_mention = 1
            publicly_mentionable_group.add(user_2)
            publicly_mentionable_group.add(Fabricate(:user))
          end

          it "displays a warning" do
            chat_page.visit_channel(channel_1)
            chat_channel_page.type_in_composer("@#{publicly_mentionable_group.name} ")

            expect(page).to have_css(".chat-mention-warnings")
            expect(page.find(".chat-mention-warnings-list__simple")).to have_content(
              publicly_mentionable_group.name,
            )
          end
        end

        context "when typing too many mentions" do
          before { SiteSetting.max_mentions_per_chat_message = 1 }

          it "displays a warning" do
            chat_page.visit_channel(channel_1)
            chat_channel_page.type_in_composer(
              "@#{user_2.username} @#{publicly_mentionable_group.name} ",
            )

            expect(page).to have_css(".chat-mention-warnings")
            expect(page.find(".chat-mention-warnings-list__simple")).to be_present
          end
        end
      end
    end
  end
end
