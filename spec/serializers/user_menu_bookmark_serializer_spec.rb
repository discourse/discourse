# frozen_string_literal: true

RSpec.describe UserMenuBookmarkSerializer do
  fab!(:user)
  fab!(:bookmarked_user, :user)

  before { register_test_bookmarkable }

  after { DiscoursePluginRegistry.reset_register!(:bookmarkables) }

  it "serializes bookmarkables that are not topics or posts" do
    bookmark = Fabricate(:bookmark, user:, bookmarkable: bookmarked_user)

    json = described_class.new(bookmark, scope: user.guardian, root: false).as_json

    expect(json[:fancy_title]).to eq(bookmarked_user.username)
    expect(json[:user][:id]).to eq(bookmarked_user.id)
  end
end
