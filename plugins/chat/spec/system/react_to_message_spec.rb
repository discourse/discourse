# frozen_string_literal: true

RSpec.describe "React to message", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:category_channel_1) { Fabricate(:category_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    category_channel_1.add(current_user)
  end

  context "when other user has reacted" do
    fab!(:reaction_1) do
      Chat::MessageReactor.new(Fabricate(:user), category_channel_1).react!(
        message_id: message_1.id,
        react_action: :add,
        emoji: "female_detective",
      )
    end

    shared_examples "inline reactions" do
      it "shows existing reactions under the message" do
        sign_in(current_user)
        chat.visit_channel(category_channel_1)
        expect(channel).to have_reaction(message_1, reaction_1)
      end

      it "increments when clicking it" do
        sign_in(current_user)
        chat.visit_channel(category_channel_1)
        channel.click_reaction(message_1, reaction_1)
        expect(channel).to have_reaction(message_1, reaction_1, 2)
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
      Chat::MessageReactor.new(Fabricate(:user), category_channel_1).react!(
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
          channel.hover_message(message_1)
          find(".chat-message-react-btn").click
          find(".chat-emoji-picker [data-emoji=\"nerd_face\"]").click

          expect(channel).to have_reaction(message_1, reaction_1)
        end

        context "when current user has multiple sessions" do
          it "adds reaction on each session" do
            reaction = OpenStruct.new(emoji: "nerd_face")

            using_session(:tab_1) do
              sign_in(current_user)
              chat.visit_channel(category_channel_1)
            end

            using_session(:tab_2) do
              sign_in(current_user)
              chat.visit_channel(category_channel_1)
            end

            using_session(:tab_1) do |session|
              channel.hover_message(message_1)
              find(".chat-message-react-btn").click
              find(".chat-emoji-picker [data-emoji=\"#{reaction.emoji}\"]").click

              expect(channel).to have_reaction(message_1, reaction)
              session.quit
            end

            using_session(:tab_2) do |session|
              expect(channel).to have_reaction(message_1, reaction)
              session.quit
            end
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
            find(".chat-emoji-picker [data-emoji=\"nerd_face\"]").click

            expect(channel).to have_reaction(message_1, reaction_1)
          end
        end

        context "when using frequent reactions" do
          it "adds a reaction" do
            sign_in(current_user)
            chat.visit_channel(category_channel_1)
            channel.hover_message(message_1)
            find(".chat-message-actions [data-emoji-name=\"+1\"").click

            expect(channel.message_reactions_list(message_1)).to have_css(
              "[data-emoji-name=\"+1\"]",
            )
          end
        end
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
        expect(channel).to have_reaction(message_1, reaction_1)
      end

      it "removes it when clicking it" do
        sign_in(current_user)
        chat.visit_channel(category_channel_1)
        channel.click_reaction(message_1, reaction_1)
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
      fab!(:user_1) { Fabricate(:user) }

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

        expect(channel).to have_reaction(message_1, reaction_2, "1")
      end
    end
  end
end
