# frozen_string_literal: true

RSpec.describe "Mentions warnings", type: :system do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:channel_2, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap(current_user, [channel_1, channel_2])
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
          channel_page.type_in_composer("@#{admin_mentionable_group.name} ")

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
        fab!(:user_2, :user)

        context "when the group has too many members" do
          before do
            SiteSetting.max_users_notified_per_group_mention = 1
            publicly_mentionable_group.add(user_2)
            publicly_mentionable_group.add(Fabricate(:user))
          end

          it "displays a warning" do
            chat_page.visit_channel(channel_1)
            channel_page.type_in_composer("@#{publicly_mentionable_group.name} ")

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
            channel_page.type_in_composer(
              "@#{user_2.username} @#{publicly_mentionable_group.name} ",
            )

            expect(page).to have_css(".chat-mention-warnings")
            expect(page.find(".chat-mention-warnings-list__simple")).to be_present
          end

          it "doesn’t count duplicates" do
            chat_page.visit_channel(channel_1)
            channel_page.type_in_composer("@#{user_2.username} @#{user_2.username} ")

            expect(page).to have_no_css(".chat-mention-warnings")
          end

          it "doesn't consider code-blocks when counting mentions" do
            raw =
              "Hey @#{user_2.username}\n\n```\ndef foo\n  @#{publicly_mentionable_group.name} = true\nend\n```\n"
            message_1 =
              Fabricate(:chat_message, user: current_user, chat_channel: channel_1, message: raw)
            chat_page.visit_channel(channel_1)

            channel_page.messages.edit(message_1)

            expect(page).to have_no_css(".chat-mention-warnings")
          end
        end
      end
    end

    context "when channel has allow_channel_wide_mentions disabled" do
      before { channel_1.update(allow_channel_wide_mentions: false) }

      %w[@here @all].each do |mention_text|
        it "displays a warning" do
          chat_page.visit_channel(channel_1)
          channel_page.type_in_composer(mention_text)

          expect(page).to have_css(".chat-mention-warnings")
          expect(page.find(".chat-mention-warnings-list__simple")).to be_present
        end
      end

      it "retains warnings when loading drafts or changing channels with no draft" do
        Chat::Draft.create!(
          chat_channel: channel_1,
          user: current_user,
          data: { message: "@all" }.to_json,
        )
        chat_page.visit_channel(channel_1)

        # Channel 1 has a draft that causes a mention warning. Should appear on load
        expect(page).to have_css(".chat-mention-warnings")
        expect(page.find(".chat-mention-warnings-list__simple")).to be_present

        # Channel 2 doesn't have a draft so it should disappear
        chat_page.visit_channel(channel_2)
        expect(page).to have_no_css(".chat-mention-warnings")

        # Navigating back to channel 1 will make the mention warnings appear b/c the draft
        # will trigger the @all mention warning again
        chat_page.visit_channel(channel_1)
        expect(page).to have_css(".chat-mention-warnings")
        expect(page.find(".chat-mention-warnings-list__simple")).to be_present
      end
    end
  end
end
