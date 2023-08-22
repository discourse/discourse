# frozen_string_literal: true

RSpec.describe "New message", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    # simpler user search without having to worry about user search data
    SiteSetting.enable_names = false

    chat_system_bootstrap
    sign_in(current_user)
  end

  it "cmd + k opens new message" do
    visit("/")
    chat_page.open_new_message

    expect(chat_page.message_creator).to be_opened
  end

  context "when public channels are disabled" do
    fab!(:channel_1) { Fabricate(:chat_channel) }

    before do
      SiteSetting.enable_public_channels = false
      channel_1.add(current_user)
    end

    it "doesn’t list public channels" do
      visit("/")
      chat_page.open_new_message

      expect(chat_page.message_creator).to be_not_listing(channel_1)
    end

    it "has a correct placeholder" do
      visit("/")
      chat_page.open_new_message

      expect(chat_page.message_creator.input["placeholder"]).to eq(
        I18n.t("js.chat.new_message_modal.default_user_search_placeholder"),
      )
    end
  end

  context "when selecting more users than allowed" do
    fab!(:current_user) { Fabricate(:trust_level_1) }
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }

    before { SiteSetting.chat_max_direct_message_users = 1 }

    it "shows an error" do
      visit("/")
      chat_page.open_new_message
      chat_page.message_creator.filter(user_1.username)
      chat_page.message_creator.shift_click_row(user_1)
      chat_page.message_creator.filter(user_2.username)
      chat_page.message_creator.shift_click_row(user_2)
      chat_page.message_creator.click_cta

      expect(page).to have_content(
        I18n.t(
          "chat.errors.over_chat_max_direct_message_users",
          count: SiteSetting.chat_max_direct_message_users,
        ),
      )
    end
  end

  context "when public channels are disabled and user can't create direct message" do
    fab!(:current_user) { Fabricate(:user) }

    before do
      SiteSetting.enable_public_channels = false
      SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:staff]
    end

    it "doesn’t list public channels" do
      visit("/")
      chat_page.open_new_message(ensure_open: false)

      expect(chat_page.message_creator).to be_closed
    end
  end

  context "when the content is not filtered" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:channel_2) { Fabricate(:chat_channel) }
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:direct_message_channel_1) do
      Fabricate(:direct_message_channel, users: [current_user, user_1])
    end
    fab!(:direct_message_channel_2) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }

    before { channel_1.add(current_user) }

    it "lists channels the user is following" do
      visit("/")
      chat_page.open_new_message

      expect(chat_page.message_creator).to be_listing(channel_1)
      expect(chat_page.message_creator).to be_not_listing(channel_2)
      expect(chat_page.message_creator).to be_not_listing(direct_message_channel_2)
      expect(chat_page.message_creator).to be_listing(user_1)
      expect(chat_page.message_creator).to be_not_listing(user_2)
    end
  end

  context "with no selection" do
    context "with unread state" do
      fab!(:user_1) { Fabricate(:user) }
      fab!(:channel_1) { Fabricate(:chat_channel) }
      fab!(:channel_2) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

      before do
        channel_1.add(user_1)
        channel_1.add(current_user)
        Fabricate(:chat_message, chat_channel: channel_1, user: user_1)
        Fabricate(:chat_message, chat_channel: channel_2, user: user_1)
      end

      it "shows the correct state" do
        visit("/")
        chat_page.open_new_message

        expect(chat_page.message_creator).to have_unread_row(channel_1, urgent: false)
        expect(chat_page.message_creator).to have_unread_row(user_1, urgent: true)
      end
    end

    context "when clicking a row" do
      context "when the row is a channel" do
        fab!(:channel_1) { Fabricate(:chat_channel) }

        before { channel_1.add(current_user) }

        it "opens the channel" do
          visit("/")
          chat_page.open_new_message
          chat_page.message_creator.click_row(channel_1)

          expect(chat_page).to have_drawer(channel_id: channel_1.id)
        end
      end

      context "when the row is a user" do
        fab!(:user_1) { Fabricate(:user) }
        fab!(:channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

        it "opens the channel" do
          visit("/")
          chat_page.open_new_message
          chat_page.message_creator.click_row(user_1)

          expect(chat_page).to have_drawer(channel_id: channel_1.id)
        end
      end
    end

    context "when shift clicking a row" do
      context "when the row is a channel" do
        fab!(:channel_1) { Fabricate(:chat_channel) }

        before { channel_1.add(current_user) }

        it "opens the channel" do
          visit("/")
          chat_page.open_new_message
          chat_page.message_creator.shift_click_row(channel_1)

          expect(chat_page).to have_drawer(channel_id: channel_1.id)
        end
      end

      context "when the row is a user" do
        fab!(:user_1) { Fabricate(:user) }
        fab!(:channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

        it "adds the user" do
          visit("/")
          chat_page.open_new_message
          chat_page.message_creator.shift_click_row(user_1)

          expect(chat_page.message_creator).to be_selecting(user_1)
        end
      end
    end

    context "when pressing enter" do
      context "when the row is a channel" do
        fab!(:channel_1) { Fabricate(:chat_channel) }

        before { channel_1.add(current_user) }

        it "opens the channel" do
          visit("/")
          chat_page.open_new_message
          chat_page.message_creator.click_row(channel_1)

          expect(chat_page).to have_drawer(channel_id: channel_1.id)
        end
      end

      context "when the row is a user" do
        fab!(:user_1) { Fabricate(:user) }
        fab!(:channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

        it "opens the channel" do
          visit("/")
          chat_page.open_new_message
          chat_page.message_creator.click_row(user_1)

          expect(chat_page).to have_drawer(channel_id: channel_1.id)
        end
      end
    end

    context "when pressing shift+enter" do
      context "when the row is a channel" do
        fab!(:channel_1) { Fabricate(:chat_channel) }

        before { channel_1.add(current_user) }

        it "opens the channel" do
          visit("/")
          chat_page.open_new_message
          chat_page.message_creator.shift_enter_shortcut

          expect(chat_page).to have_drawer(channel_id: channel_1.id)
        end
      end

      context "when the row is a user" do
        fab!(:user_1) { Fabricate(:user) }
        fab!(:channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

        it "adds the user" do
          visit("/")
          chat_page.open_new_message
          chat_page.message_creator.shift_enter_shortcut

          expect(chat_page.message_creator).to be_selecting(user_1)
        end
      end
    end

    context "when navigating content with arrows" do
      fab!(:channel_1) { Fabricate(:chat_channel, name: "channela") }
      fab!(:channel_2) { Fabricate(:chat_channel, name: "channelb") }

      before do
        channel_1.add(current_user)
        channel_2.add(current_user)
      end

      it "changes active content" do
        visit("/")
        chat_page.open_new_message

        expect(chat_page.message_creator).to be_listing(channel_1, active: true)

        chat_page.message_creator.arrow_down_shortcut

        expect(chat_page.message_creator).to be_listing(channel_2, active: true)

        chat_page.message_creator.arrow_down_shortcut

        expect(chat_page.message_creator).to be_listing(channel_1, active: true)

        chat_page.message_creator.arrow_up_shortcut

        expect(chat_page.message_creator).to be_listing(channel_2, active: true)
      end
    end

    context "with disabled content" do
      fab!(:user_1) { Fabricate(:user) }
      fab!(:channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

      before { user_1.user_option.update!(chat_enabled: false) }

      it "doesn’t make the content active" do
        visit("/")
        chat_page.open_new_message

        expect(chat_page.message_creator).to be_listing(user_1, inactive: true, disabled: true)
      end
    end
  end

  context "when filtering" do
    fab!(:channel_1) { Fabricate(:chat_channel, name: "bob-channel") }
    fab!(:user_1) { Fabricate(:user, username: "bob-user") }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:channel_2) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }
    fab!(:channel_3) { Fabricate(:direct_message_channel, users: [current_user, user_1, user_2]) }

    before { channel_1.add(current_user) }

    context "when query is the name of the category" do
      fab!(:category) { Fabricate(:category, name: "dev") }
      fab!(:channel_1) { Fabricate(:category_channel, chatable: category, name: "something dev") }
      fab!(:channel_2) { Fabricate(:category_channel, chatable: category, name: "something else") }

      it "favors the channel name" do
        visit("/")
        chat_page.open_new_message

        chat_page.message_creator.filter("dev")

        expect(chat_page.message_creator).to be_listing(channel_1)
        expect(chat_page.message_creator).to be_not_listing(channel_2)
      end
    end

    context "with no prefix" do
      it "lists all matching content" do
        visit("/")
        chat_page.open_new_message

        chat_page.message_creator.filter("bob")

        expect(chat_page.message_creator).to be_listing(channel_1)
        expect(chat_page.message_creator).to be_not_listing(channel_2)
        expect(chat_page.message_creator).to be_listing(channel_3)
        expect(chat_page.message_creator).to be_listing(user_1)
        expect(chat_page.message_creator).to be_not_listing(user_2)
      end
    end

    context "with channel prefix" do
      it "lists matching channel" do
        visit("/")
        chat_page.open_new_message

        chat_page.message_creator.filter("#bob")

        expect(chat_page.message_creator).to be_listing(channel_1)
        expect(chat_page.message_creator).to be_not_listing(channel_2)
        expect(chat_page.message_creator).to be_listing(channel_3)
        expect(chat_page.message_creator).to be_not_listing(user_1)
        expect(chat_page.message_creator).to be_not_listing(user_2)
      end
    end

    context "with user prefix" do
      it "lists matching users" do
        visit("/")
        chat_page.open_new_message

        chat_page.message_creator.filter("@bob")

        expect(chat_page.message_creator).to be_not_listing(channel_1)
        expect(chat_page.message_creator).to be_not_listing(channel_2)
        expect(chat_page.message_creator).to be_not_listing(channel_3)
        expect(chat_page.message_creator).to be_listing(user_1)
        expect(chat_page.message_creator).to be_not_listing(user_2)
      end
    end
  end

  context "with selection" do
    fab!(:channel_1) { Fabricate(:chat_channel, name: "bob-channel") }
    fab!(:user_1) { Fabricate(:user, username: "bob-user") }
    fab!(:user_2) { Fabricate(:user, username: "bobby-user") }
    fab!(:user_3) { Fabricate(:user, username: "sam-user") }
    fab!(:channel_2) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }
    fab!(:channel_3) { Fabricate(:direct_message_channel, users: [current_user, user_2]) }

    before do
      channel_1.add(current_user)
      visit("/")
      chat_page.open_new_message
      chat_page.message_creator.shift_click_row(user_1)
    end

    context "when pressing enter" do
      it "opens the channel" do
        chat_page.message_creator.enter_shortcut

        expect(chat_page).to have_drawer(channel_id: channel_2.id)
      end
    end

    context "when clicking cta" do
      it "opens the channel" do
        chat_page.message_creator.click_cta

        expect(chat_page).to have_drawer(channel_id: channel_2.id)
      end
    end

    context "when filtering" do
      it "shows only matching users regarless of prefix" do
        chat_page.message_creator.filter("#bob")

        expect(chat_page.message_creator).to be_listing(user_1)
        expect(chat_page.message_creator).to be_listing(user_2)
        expect(chat_page.message_creator).to be_not_listing(user_3)
        expect(chat_page.message_creator).to be_not_listing(channel_1)
        expect(chat_page.message_creator).to be_not_listing(channel_2)
        expect(chat_page.message_creator).to be_not_listing(channel_3)
      end

      it "shows selected user as selected in content" do
        chat_page.message_creator.filter("@bob")

        expect(chat_page.message_creator).to be_listing(user_1, selected: true)
        expect(chat_page.message_creator).to be_listing(user_2, selected: false)
      end
    end

    context "when clicking another user" do
      it "adds it to the selection" do
        chat_page.message_creator.filter("@bob")
        chat_page.message_creator.click_row(user_2)

        expect(chat_page.message_creator).to be_selecting(user_1)
        expect(chat_page.message_creator).to be_selecting(user_2)
      end
    end

    context "when pressing backspace" do
      it "removes it" do
        chat_page.message_creator.backspace_shortcut

        expect(chat_page.message_creator).to be_selecting(user_1, active: true)

        chat_page.message_creator.backspace_shortcut

        expect(chat_page.message_creator).to be_not_selecting(user_1)
      end
    end

    context "when navigating selection with arrow left/right" do
      it "changes active item" do
        chat_page.message_creator.filter("@bob")
        chat_page.message_creator.click_row(user_2)

        chat_page.message_creator.arrow_left_shortcut

        expect(chat_page.message_creator).to be_selecting(user_2, active: true)

        chat_page.message_creator.arrow_left_shortcut

        expect(chat_page.message_creator).to be_selecting(user_1, active: true)

        chat_page.message_creator.arrow_left_shortcut

        expect(chat_page.message_creator).to be_selecting(user_2, active: true)

        chat_page.message_creator.arrow_right_shortcut

        expect(chat_page.message_creator).to be_selecting(user_1, active: true)
      end
    end

    context "when clicking selection" do
      it "removes it" do
        chat_page.message_creator.click_item(user_1)

        expect(chat_page.message_creator).to be_not_selecting(user_1)
      end
    end
  end
end
