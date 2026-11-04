# frozen_string_literal: true

RSpec.describe AdminDetailedUserSerializer do
  fab!(:admin)
  fab!(:bot)

  def serialize(user, viewer)
    described_class.new(user, scope: viewer.guardian, root: false).as_json
  end

  it "includes chat discovery only for bots other than the system user, viewed by admins" do
    Chat::DiscoverableBot.create!(user: bot)
    expect(serialize(bot, admin)[:chat_discoverable]).to eq(true)
    expect(serialize(bot, Fabricate(:moderator))).not_to have_key(:chat_discoverable)
    expect(serialize(admin, admin)).not_to have_key(:chat_discoverable)
    expect(serialize(Discourse.system_user, admin)).not_to have_key(:chat_discoverable)
  end
end
