# frozen_string_literal: true

RSpec.describe "Flag message", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }

  fab!(:current_user) { Fabricate(:user) }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  it "lists preloaded channels by default" do
    channel_1 = Fabricate(:chat_channel)
    channel_1.add(current_user)

    visit("/")
    chat_page.open_new_message

    expect(chat_page.message_creator).to be_listing(channel_1)
  end

  it "can filter channels" do
    channel_1 = Fabricate(:chat_channel)
    channel_2 = Fabricate(:chat_channel)
    channel_1.add(current_user)
    channel_2.add(current_user)

    visit("/")
    chat_page.open_new_message
    chat_page.message_creator.filter(channel_2.title)

    expect(chat_page.message_creator).to be_listing(channel_2)
    expect(chat_page.message_creator).to be_not_listing(channel_1)
  end

  it "can filter users" do
    user_1 = Fabricate(:user)
    user_2 = Fabricate(:user)

    visit("/")
    chat_page.open_new_message
    chat_page.message_creator.filter(user_2.username)

    expect(chat_page.message_creator).to be_listing(user_2)
    expect(chat_page.message_creator).to be_not_listing(user_1)
  end

  it "can filter direct message channels" do
    channel_1 = Fabricate(:direct_message_channel, users: [current_user])
    channel_2 =
      Fabricate(
        :direct_message_channel,
        users: [current_user, Fabricate(:user), Fabricate(:user, username: "user_1")],
      )

    visit("/")
    chat_page.open_new_message
    chat_page.message_creator.filter("user_1")

    expect(chat_page.message_creator).to be_listing(channel_2)
    expect(chat_page.message_creator).to be_not_listing(channel_1)
  end

  it "can create a new group message" do
    user_1 = Fabricate(:user)
    user_2 = Fabricate(:user)

    visit("/")
    chat_page.prefers_full_page
    chat_page.open_new_message
    chat_page.find("#new-group-chat").click
    chat_page.find(".chat-message-creator__new-group-header__input").fill_in(with: "cats")
    chat_page.find(".chat-message-creator__members-input").fill_in(with: user_1.username)
    chat_page.message_creator.click_row(user_1)
    chat_page.find(".chat-message-creator__members-input").fill_in(with: user_2.username)
    chat_page.message_creator.click_row(user_2)
    page.find(".create-chat-group").click

    expect(page).to have_current_path(%r{/chat/c/cats/\d+})
  end
end
