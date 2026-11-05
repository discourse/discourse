# frozen_string_literal: true

describe "Admin live rooms" do
  fab!(:admin)
  fab!(:creator, :user)
  fab!(:room) { Fabricate(:live_room, name: "Town hall", creator:) }

  let(:user_card) { PageObjects::Components::UserCard.new }

  before do
    SiteSetting.live_enabled = true
    sign_in(admin)
  end

  it "shows the room creator and opens their user card" do
    visit("/admin/plugins/live/live-rooms")

    creator_link = find(".live-rooms__creator-link", text: creator.username)
    creator_link.click

    expect(user_card).to be_showing_user(creator.username)
  end
end
