# frozen_string_literal: true

RSpec.describe "Browse page", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:browse_page) { PageObjects::Pages::ChatBrowse.new }

  before do
    sign_in(current_user)
    chat_system_bootstrap
  end

  context "when user has chat disabled" do
    before { current_user.user_option.update!(chat_enabled: false) }

    it "redirects to homepage" do
      visit("/chat/browse") # no page object here as we actually don't load it
      expect(page).to have_current_path("/latest")
    end
  end

  context "when public channels are disabled" do
    before { SiteSetting.enable_public_channels = false }

    it "redirects to homepage" do
      visit("/chat/browse") # no page object here as we actually don't load it
      expect(page).to have_current_path("/latest")
    end
  end

  context "when user has chat enabled" do
    context "when visiting browse page" do
      it "defaults to open filer" do
        chat_page.visit_browse
        expect(browse_page).to have_current_path("/chat/browse/open")
      end

      it "has the expected tabs" do
        chat_page.visit_browse
        expect(browse_page).to have_channel(name: I18n.t("js.chat.browse.filter_all"))
        expect(browse_page).to have_channel(name: I18n.t("js.chat.browse.filter_open"))
        expect(browse_page).to have_channel(name: I18n.t("js.chat.browse.filter_closed"))
      end

      it "has not archived tab available" do
        chat_page.visit_browse
        expect(browse_page).to have_no_channel(name: I18n.t("js.chat.browse.filter_archived"))
      end

      it "redirects archived tab to default tab" do
        chat_page.visit_browse(:archived)

        expect(browse_page).to have_current_path("/chat/browse/open")
      end

      context "when archiving channels is enabled" do
        before { SiteSetting.chat_allow_archiving_channels = true }

        it "has the archived tab" do
          chat_page.visit_browse
          expect(browse_page).to have_channel(name: I18n.t("js.chat.browse.filter_archived"))
        end
      end
    end

    context "when on mobile", mobile: true do
      it "has a back button" do
        chat_page.visit_browse
        find(".chat-full-page-header__back-btn").click

        expect(browse_page).to have_current_path("/chat")
      end
    end

    context "when filtering results" do
      fab!(:category_channel_1) { Fabricate(:chat_channel, name: "foo") }
      fab!(:category_channel_2) { Fabricate(:chat_channel, name: "bar") }

      context "when results are found" do
        it "lists expected results" do
          chat_page.visit_browse
          browse_page.search(category_channel_1.name)

          expect(browse_page).to have_channel(name: category_channel_1.name)
          expect(browse_page).to have_no_channel(name: category_channel_2.name)
        end
      end

      context "when results are not found" do
        it "displays the correct message" do
          chat_page.visit_browse
          browse_page.search("x")

          expect(browse_page).to have_channel(name: I18n.t("js.chat.empty_state.title"))
        end

        it "doesn’t display any channel" do
          chat_page.visit_browse
          browse_page.search("x")

          expect(browse_page).to have_no_channel(name: category_channel_1.name)
          expect(browse_page).to have_no_channel(name: category_channel_2.name)
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
          expect(browse_page).to have_no_channel(name: direct_message_channel_1.title(current_user))
        end

        it "doesn’t list destroyed channels" do
          expect(browse_page).to have_no_channel(name: category_channel_5.title)
        end
      end

      context "when filter is all" do
        it "lists all category channels" do
          chat_page.visit_browse(:all)

          expect(browse_page).to have_channel(name: category_channel_1.name)
          expect(browse_page).to have_channel(name: category_channel_2.name)
          expect(browse_page).to have_channel(name: category_channel_3.name)
          expect(browse_page).to have_channel(name: category_channel_4.name)
        end

        context "when loading more" do
          before { 25.times { Fabricate(:chat_channel, status: :open) } }

          it "works" do
            chat_page.visit_browse(:all)
            scroll_to(find(".chat-channel-card:last-child"))

            expect(browse_page).to have_selector(".chat-channel-card", count: 29)
          end
        end

        include_examples "never visible channels" do
          before { chat_page.visit_browse(:all) }
        end
      end

      context "when filter is open" do
        it "lists all opened category channels" do
          chat_page.visit_browse(:open)

          expect(browse_page).to have_channel(name: category_channel_1.name)
          expect(browse_page).to have_no_channel(name: category_channel_2.name)
          expect(browse_page).to have_no_channel(name: category_channel_3.name)
          expect(browse_page).to have_no_channel(name: category_channel_4.name)
        end

        context "when loading more" do
          fab!(:valid_channel) { Fabricate(:chat_channel, status: :open) }
          fab!(:invalid_channel) { Fabricate(:chat_channel, status: :closed) }

          it "keeps the filter" do
            chat_page.visit_browse(:open)

            expect(browse_page).to have_channel(name: valid_channel.title)
            expect(browse_page).to have_no_channel(name: invalid_channel.title)
          end
        end

        include_examples "never visible channels" do
          before { chat_page.visit_browse(:open) }
        end
      end

      context "when filter is closed" do
        it "lists all closed category channels" do
          chat_page.visit_browse(:closed)

          expect(browse_page).to have_no_channel(name: category_channel_1.name)
          expect(browse_page).to have_no_channel(name: category_channel_2.name)
          expect(browse_page).to have_channel(name: category_channel_3.name)
          expect(browse_page).to have_no_channel(name: category_channel_4.name)
        end

        context "when loading more" do
          fab!(:valid_channel) { Fabricate(:chat_channel, status: :closed) }
          fab!(:invalid_channel) { Fabricate(:chat_channel, status: :open) }

          it "keeps the filter" do
            chat_page.visit_browse(:closed)

            expect(browse_page).to have_channel(name: valid_channel.title)
            expect(browse_page).to have_no_channel(name: invalid_channel.title)
          end
        end

        include_examples "never visible channels" do
          before { chat_page.visit_browse(:closed) }
        end
      end

      context "when filter is archived" do
        before { SiteSetting.chat_allow_archiving_channels = true }

        it "lists all archived category channels" do
          chat_page.visit_browse(:archived)

          expect(browse_page).to have_no_channel(name: category_channel_1.name)
          expect(browse_page).to have_no_channel(name: category_channel_2.name)
          expect(browse_page).to have_no_channel(name: category_channel_3.name)
          expect(browse_page).to have_channel(name: category_channel_4.name)
        end

        context "when loading more" do
          fab!(:valid_channel) { Fabricate(:chat_channel, status: :archived) }
          fab!(:invalid_channel) { Fabricate(:chat_channel, status: :open) }

          it "keeps the filter" do
            chat_page.visit_browse(:archived)

            expect(browse_page).to have_channel(name: valid_channel.title)
            expect(browse_page).to have_no_channel(name: invalid_channel.title)
          end
        end

        include_examples "never visible channels" do
          before { chat_page.visit_browse(:archived) }
        end
      end
    end
  end
end
