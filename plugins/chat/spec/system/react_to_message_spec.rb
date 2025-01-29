# frozen_string_literal: true

RSpec.describe "React to message", type: :system do
  fab!(:current_user) { Fabricate(:user, group_ids: [Group::AUTO_GROUPS[:trust_level_1]]) }
  fab!(:other_user) { Fabricate(:user, group_ids: [Group::AUTO_GROUPS[:trust_level_1]]) }
  fab!(:category_channel_1) { Fabricate(:category_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    category_channel_1.add(current_user)
    category_channel_1.add(other_user)
  end

  context "when other user has reacted" do
    fab!(:reaction_1) do
      Chat::MessageReactor.new(other_user, category_channel_1).react!(
        message_id: message_1.id,
        react_action: :add,
        emoji: "female_detective",
      )
    end

    shared_examples "inline reactions" do
      it "shows existing reactions under the message" do
        sign_in(current_user)
        chat.visit_channel(category_channel_1)
        expect(channel).to have_reaction(message_1, reaction_1.emoji)
      end

      it "increments when clicking it" do
        sign_in(current_user)
        chat.visit_channel(category_channel_1)
        channel.click_reaction(message_1, reaction_1.emoji)
        expect(channel).to have_reaction(message_1, reaction_1.emoji, 2)
      end
    end

    context "when desktop" do
      include_examples "inline reactions"
    end

    context "when mobile", mobile: true do
      include_examples "inline reactions"
    end
  end

  context "when current user reacts" do
    fab!(:reaction_1) do
      Chat::MessageReactor.new(other_user, category_channel_1).react!(
        message_id: message_1.id,
        react_action: :add,
        emoji: "female_detective",
      )
    end

    context "when desktop" do
      context "when using inline reaction button" do
        it "adds a reaction" do
          sign_in(current_user)
          chat.visit_channel(category_channel_1)
          channel.react_to_message(message_1)
          find(".emoji-picker [data-emoji=\"grimacing\"]").click

          expect(channel).to have_reaction(message_1, "grimacing")
        end

        context "when current user has multiple sessions" do
          xit "adds reaction on each session" do
            reaction = "grimacing"

            sign_in(current_user)
            chat.visit_channel(category_channel_1)

            using_session(:tab_1) do
              sign_in(current_user)
              chat.visit_channel(category_channel_1)
            end

            using_session(:tab_1) do
              channel.hover_message(message_1)
              find(".react-btn").click
              find(".emoji-picker [data-emoji=\"#{reaction}\"]").click

              expect(channel).to have_reaction(message_1, reaction)
            end

            expect(channel).to have_reaction(message_1, "grimacing")
          end
        end
      end

      context "when using message actions menu" do
        context "when using the emoji picker" do
          it "adds a reaction" do
            sign_in(current_user)
            chat.visit_channel(category_channel_1)
            channel.hover_message(message_1)
            find(".chat-message-actions .react-btn").click
            find(".emoji-picker [data-emoji=\"nerd_face\"]").click

            expect(channel).to have_reaction(message_1, reaction_1.emoji)
          end

          it "removes denied emojis and aliases from reactions" do
            SiteSetting.emoji_deny_list = "fu"

            sign_in(current_user)
            chat.visit_channel(category_channel_1)
            channel.hover_message(message_1)
            find(".chat-message-actions .react-btn").click

            expect(page).to have_no_css(".emoji-picker [data-emoji=\"fu\"]")
            expect(page).to have_no_css(".emoji-picker [data-emoji=\"middle_finger\"]")
          end
        end

        context "when using favorite reactions" do
          it "adds a reaction" do
            sign_in(current_user)
            chat.visit_channel(category_channel_1)
            channel.hover_message(message_1)
            find(".chat-message-actions [data-emoji-name=\"+1\"]").click

            expect(channel.message_reactions_list(message_1)).to have_css(
              "[data-emoji-name=\"+1\"]",
            )
          end
        end
      end
    end

    context "when mobile", mobile: true do
      context "when using favorite reactions" do
        it "adds a reaction" do
          sign_in(current_user)
          chat.visit_channel(category_channel_1)
          channel.expand_message_actions_mobile(message_1)
          find(".main-actions [data-emoji-name=\"+1\"]").click

          expect(channel.message_reactions_list(message_1)).to have_css("[data-emoji-name=\"+1\"]")
        end
      end
    end
  end

  context "when current user and another have reacted" do
    fab!(:other_user) { Fabricate(:user, group_ids: [Group::AUTO_GROUPS[:trust_level_1]]) }

    fab!(:reaction_1) do
      Chat::MessageReactor.new(current_user, category_channel_1).react!(
        message_id: message_1.id,
        react_action: :add,
        emoji: "female_detective",
      )
    end

    fab!(:reaction_2) do
      Chat::MessageReactor.new(other_user, category_channel_1).react!(
        message_id: message_1.id,
        react_action: :add,
        emoji: "female_detective",
      )
    end

    context "when removing the reaction" do
      it "removes only the reaction from the current user" do
        sign_in(current_user)
        chat.visit_channel(category_channel_1)

        expect(channel).to have_reaction(message_1, "female_detective", "2")

        channel.click_reaction(message_1, "female_detective")

        expect(channel).to have_reaction(message_1, "female_detective", "1")
      end
    end
  end

  context "when current user has reacted" do
    fab!(:reaction_1) do
      Chat::MessageReactor.new(current_user, category_channel_1).react!(
        message_id: message_1.id,
        react_action: :add,
        emoji: "female_detective",
      )
    end

    shared_examples "inline reactions" do
      it "shows existing reactions under the message" do
        sign_in(current_user)
        chat.visit_channel(category_channel_1)
        expect(channel).to have_reaction(message_1, reaction_1.emoji)
      end

      it "removes it when clicking it" do
        sign_in(current_user)
        chat.visit_channel(category_channel_1)
        channel.click_reaction(message_1, reaction_1.emoji)
        expect(channel).to have_no_reactions(message_1)
      end
    end

    context "when desktop" do
      include_examples "inline reactions"
    end

    context "when mobile", mobile: true do
      include_examples "inline reactions"
    end

    context "when receiving a duplicate reaction event" do
      fab!(:user_1) { Fabricate(:user, group_ids: [Group::AUTO_GROUPS[:trust_level_1]]) }

      fab!(:reaction_2) do
        Chat::MessageReactor.new(user_1, category_channel_1).react!(
          message_id: message_1.id,
          react_action: :add,
          emoji: "heart",
        )
      end

      it "doesn’t create duplicate reactions" do
        sign_in(current_user)
        chat.visit_channel(category_channel_1)

        Chat::Publisher.publish_reaction!(category_channel_1, message_1, "add", user_1, "heart")
        channel.send_message("test") # cheap trick to ensure reaction has been processed

        expect(channel).to have_reaction(message_1, reaction_2.emoji, "1")
      end
    end
  end
end
