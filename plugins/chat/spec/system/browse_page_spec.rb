# frozen_string_literal: true

RSpec.describe "Browse page", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }

  def browse_view
    page.find(".chat-browse-view")
  end

  before do
    sign_in(current_user)
    chat_system_bootstrap
  end

  context "when user has chat disabled" do
    before { current_user.user_option.update!(chat_enabled: false) }

    it "redirects to homepage" do
      visit("/chat/browse")

      expect(page).to have_current_path("/latest")
    end
  end

  context "when user has chat enabled" do
    context "when visiting browse page" do
      it "defaults to open filer" do
        visit("/chat/browse")

        expect(page).to have_current_path("/chat/browse/open")
      end

      it "has the expected tabs" do
        visit("/chat/browse")

        expect(browse_view).to have_content(I18n.t("js.chat.browse.filter_all"))
        expect(browse_view).to have_content(I18n.t("js.chat.browse.filter_open"))
        expect(browse_view).to have_content(I18n.t("js.chat.browse.filter_closed"))
      end

      it "has not archived tab available" do
        visit("/chat/browse")

        expect(browse_view).to have_no_content(I18n.t("js.chat.browse.filter_archived"))
      end

      it "redirects archived tab to default tab" do
        visit("/chat/browse/archived")

        expect(page).to have_current_path("/chat/browse/open")
      end

      context "when archiving channels is enabled" do
        before { SiteSetting.chat_allow_archiving_channels = true }

        it "has the archived tab" do
          visit("/chat/browse")

          expect(browse_view).to have_content(I18n.t("js.chat.browse.filter_archived"))
        end
      end
    end

    context "when on mobile", mobile: true do
      it "has a back button" do
        visit("/chat/browse")
        find(".chat-full-page-header__back-btn").click

        expect(page).to have_current_path("/chat")
      end
    end

    context "when filtering resuls" do
      fab!(:category_channel_1) { Fabricate(:chat_channel, name: "foo") }
      fab!(:category_channel_2) { Fabricate(:chat_channel, name: "bar") }

      context "when results are found" do
        it "lists expected results" do
          visit("/chat/browse")
          find(".dc-filter-input").fill_in(with: category_channel_1.name)

          expect(browse_view).to have_content(category_channel_1.name)
          expect(browse_view).to have_no_content(category_channel_2.name)
        end
      end

      context "when results are not found" do
        it "displays the correct message" do
          visit("/chat/browse")
          find(".dc-filter-input").fill_in(with: "x")

          expect(browse_view).to have_content(I18n.t("js.chat.empty_state.title"))
        end

        it "doesn’t display any channel" do
          visit("/chat/browse")
          find(".dc-filter-input").fill_in(with: "x")

          expect(browse_view).to have_no_content(category_channel_1.name)
          expect(browse_view).to have_no_content(category_channel_2.name)
        end
      end
    end

    context "when visiting tabs" do
      fab!(:category_channel_1) { Fabricate(:chat_channel, status: :open) }
      fab!(:category_channel_2) { Fabricate(:chat_channel, status: :read_only) }
      fab!(:category_channel_3) { Fabricate(:chat_channel, status: :closed) }
      fab!(:category_channel_4) { Fabricate(:chat_channel, status: :archived) }
      fab!(:category_channel_5) { Fabricate(:chat_channel, status: :open) }
      fab!(:direct_message_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

      before { category_channel_5.destroy! }

      shared_examples "never visible channels" do
        it "doesn’t list direct message channel" do
          expect(browse_view).to have_no_content(direct_message_channel_1.title(current_user))
        end

        it "doesn’t list destroyed channels" do
          expect(browse_view).to have_no_content(category_channel_5.title)
        end
      end

      context "when filter is all" do
        it "lists all category channels" do
          visit("/chat/browse/all")

          expect(browse_view).to have_content(category_channel_1.name)
          expect(browse_view).to have_content(category_channel_2.name)
          expect(browse_view).to have_content(category_channel_3.name)
          expect(browse_view).to have_content(category_channel_4.name)
        end

        context "when loading more" do
          before { 25.times { Fabricate(:chat_channel, status: :open) } }

          it "works" do
            visit("/chat/browse/all")
            scroll_to(find(".chat-channel-card:last-child"))

            expect(page).to have_selector(".chat-channel-card", count: 29)
          end
        end

        include_examples "never visible channels" do
          before { visit("/chat/browse/all") }
        end
      end

      context "when filter is open" do
        it "lists all opened category channels" do
          visit("/chat/browse/open")

          expect(browse_view).to have_content(category_channel_1.name)
          expect(browse_view).to have_no_content(category_channel_2.name)
          expect(browse_view).to have_no_content(category_channel_3.name)
          expect(browse_view).to have_no_content(category_channel_4.name)
        end

        context "when loading more" do
          fab!(:valid_channel) { Fabricate(:chat_channel, status: :open) }
          fab!(:invalid_channel) { Fabricate(:chat_channel, status: :closed) }

          it "keeps the filter" do
            visit("/chat/browse/open")

            expect(page).to have_content(valid_channel.title)
            expect(page).to have_no_content(invalid_channel.title)
          end
        end

        include_examples "never visible channels" do
          before { visit("/chat/browse/open") }
        end
      end

      context "when filter is closed" do
        it "lists all closed category channels" do
          visit("/chat/browse/closed")

          expect(browse_view).to have_no_content(category_channel_1.name)
          expect(browse_view).to have_no_content(category_channel_2.name)
          expect(browse_view).to have_content(category_channel_3.name)
          expect(browse_view).to have_no_content(category_channel_4.name)
        end

        context "when loading more" do
          fab!(:valid_channel) { Fabricate(:chat_channel, status: :closed) }
          fab!(:invalid_channel) { Fabricate(:chat_channel, status: :open) }

          it "keeps the filter" do
            visit("/chat/browse/closed")

            expect(page).to have_content(valid_channel.title)
            expect(page).to have_no_content(invalid_channel.title)
          end
        end

        include_examples "never visible channels" do
          before { visit("/chat/browse/closed") }
        end
      end

      context "when filter is archived" do
        before { SiteSetting.chat_allow_archiving_channels = true }

        it "lists all archived category channels" do
          visit("/chat/browse/archived")

          expect(browse_view).to have_no_content(category_channel_1.name)
          expect(browse_view).to have_no_content(category_channel_2.name)
          expect(browse_view).to have_no_content(category_channel_3.name)
          expect(browse_view).to have_content(category_channel_4.name)
        end

        context "when loading more" do
          fab!(:valid_channel) { Fabricate(:chat_channel, status: :archived) }
          fab!(:invalid_channel) { Fabricate(:chat_channel, status: :open) }

          it "keeps the filter" do
            visit("/chat/browse/archived")

            expect(page).to have_content(valid_channel.title)
            expect(page).to have_no_content(invalid_channel.title)
          end
        end

        include_examples "never visible channels" do
          before { visit("/chat/browse/archived") }
        end
      end
    end
  end
end
