# frozen_string_literal: true

RSpec.describe "Visit channel", type: :system, js: true do
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:current_user) { Fabricate(:user) }
  fab!(:category_channel_1) { Fabricate(:category_channel) }
  fab!(:private_category_channel_1) { Fabricate(:private_category_channel) }
  fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }
  fab!(:inaccessible_dm_channel_1) { Fabricate(:direct_message_channel) }

  let(:chat) { PageObjects::Pages::Chat.new }

  before { chat_system_bootstrap }

  context "when chat disabled" do
    before do
      SiteSetting.chat_enabled = false
      sign_in(current_user)
    end

    it "shows a not found page" do
      chat.visit_channel(category_channel_1)

      expect(page).to have_content(I18n.t("page_not_found.title"))
    end
  end

  context "when chat enabled" do
    context "when anonymous" do
      it "redirects to homepage" do
        chat.visit_channel(category_channel_1)

        expect(page).to have_current_path("/latest")
      end
    end

    context "when regular user" do
      before { sign_in(current_user) }

      context "when chat is disabled" do
        before { current_user.user_option.update!(chat_enabled: false) }

        it "redirects to homepage" do
          chat.visit_channel(category_channel_1)

          expect(page).to have_current_path("/latest")
        end
      end

      context "when current user is not allowed to chat" do
        before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff] }

        it "redirects homepage" do
          chat.visit_channel(category_channel_1)

          expect(page).to have_current_path("/latest")
        end
      end

      context "when channel is not found" do
        it "shows an error" do
          visit("/chat/c/-/999")

          expect(page).to have_content("Not Found") # this is not a translated key
        end
      end

      context "when loading a non existing message of a channel" do
        it "shows an error" do
          visit("/chat/c/-/#{category_channel_1.id}/-999")

          expect(page).to have_content(I18n.t("not_found"))
        end
      end

      context "when channel is not accessible" do
        context "when category channel" do
          it "shows an error" do
            chat.visit_channel(private_category_channel_1)

            expect(page).to have_content(I18n.t("invalid_access"))
          end
        end

        context "when direct message channel" do
          it "shows an error" do
            chat.visit_channel(inaccessible_dm_channel_1)

            expect(page).to have_content(I18n.t("invalid_access"))
          end
        end
      end

      context "when category channel is read-only" do
        fab!(:readonly_category_1) { Fabricate(:private_category, group: Fabricate(:group)) }
        fab!(:readonly_group_1) { Fabricate(:group, users: [current_user]) }
        fab!(:readonly_category_channel_1) do
          Fabricate(:private_category_channel, group: readonly_group_1)
        end
        fab!(:message_1) { Fabricate(:chat_message, chat_channel: readonly_category_channel_1) }

        before do
          Fabricate(
            :category_group,
            category: readonly_category_1,
            group: readonly_group_1,
            permission_type: CategoryGroup.permission_types[:readonly],
          )
        end

        it "doesn't allow user to join it" do
          chat.visit_channel(readonly_category_channel_1)

          expect(page).not_to have_content(I18n.t("js.chat.channel_settings.join_channel"))
        end

        it "shows a preview of the channel" do
          chat.visit_channel(readonly_category_channel_1)

          expect(page).to have_content(readonly_category_channel_1.name)
          expect(chat).to have_message(message_1)
        end
      end

      context "when current user is not member of the channel" do
        context "when category channel" do
          fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

          it "allows to join it" do
            chat.visit_channel(category_channel_1)

            expect(page).to have_content(I18n.t("js.chat.channel_settings.join_channel"))
          end

          it "shows a preview of the channel" do
            chat.visit_channel(category_channel_1)

            expect(page).to have_content(category_channel_1.name)
            expect(chat).to have_message(message_1)
          end
        end

        context "when direct message channel" do
          fab!(:message_1) { Fabricate(:chat_message, chat_channel: dm_channel_1) }

          before { dm_channel_1.membership_for(current_user).destroy! }

          it "allows to join it" do
            chat.visit_channel(dm_channel_1)

            expect(page).to have_content(I18n.t("js.chat.channel_settings.join_channel"))
          end

          it "shows a preview of the channel" do
            chat.visit_channel(dm_channel_1)

            expect(chat).to have_message(message_1)
          end
        end
      end

      context "when current user is member of the channel" do
        context "when category channel" do
          fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

          before { category_channel_1.add(current_user) }

          it "doesn’t ask to join it" do
            chat.visit_channel(category_channel_1)

            expect(page).to have_no_content(I18n.t("js.chat.channel_settings.join_channel"))
          end

          it "shows a preview of the channel" do
            chat.visit_channel(category_channel_1)

            expect(page).to have_content(category_channel_1.name)
            expect(chat).to have_message(message_1)
          end

          context "when URL doesn’t contain slug" do
            it "redirects to correct URL" do
              visit("/chat/c/-/#{category_channel_1.id}")

              expect(page).to have_current_path(
                "/chat/c/#{category_channel_1.slug}/#{category_channel_1.id}",
              )
            end
          end
        end

        context "when direct message channel" do
          fab!(:message_1) do
            Fabricate(:chat_message, chat_channel: dm_channel_1, user: current_user)
          end

          it "doesn’t ask to join it" do
            chat.visit_channel(dm_channel_1)

            expect(page).to have_no_content(I18n.t("js.chat.channel_settings.join_channel"))
          end

          it "shows a preview of the channel" do
            chat.visit_channel(dm_channel_1)

            expect(chat).to have_message(message_1)
          end

          context "when URL doesn’t contain slug" do
            it "redirects to correct URL" do
              visit("/chat/c/-/#{dm_channel_1.id}")

              expect(page).to have_current_path(
                "/chat/c/#{Slug.for(dm_channel_1.title(current_user))}/#{dm_channel_1.id}",
              )
            end
          end
        end
      end
    end
  end
end
