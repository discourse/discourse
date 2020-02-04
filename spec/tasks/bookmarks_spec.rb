# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "bookmarks tasks" do
  let(:user1) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }
  let(:user3) { Fabricate(:user) }
  let(:post1) { Fabricate(:post) }
  let(:post2) { Fabricate(:post) }
  let(:post3) { Fabricate(:post) }

  before do
    Rake::Task.clear
    Discourse::Application.load_tasks

    create_post_actions_and_existing_bookmarks
  end

  it "migrates all PostActions" do
    Rake::Task['bookmarks:sync_to_table'].invoke

    expect(Bookmark.all.count).to eq(3)
  end

  it "does not create bookmarks that already exist in the bookmarks table for a user" do
    Fabricate(:bookmark, user: user1, post: post1)

    Rake::Task['bookmarks:sync_to_table'].invoke

    expect(Bookmark.all.count).to eq(3)
    expect(Bookmark.where(post: post1, user: user1).count).to eq(1)
  end

  it "respects the sync_limit if provided and stops creating bookmarks at the limit (so this can be run progrssively" do
    Rake::Task['bookmarks:sync_to_table'].invoke(1)
    expect(Bookmark.all.count).to eq(1)
  end

  def create_post_actions_and_existing_bookmarks
    Fabricate(:post_action, user: user1, post: post1, post_action_type_id: PostActionType.types[:bookmark])
    Fabricate(:post_action, user: user2, post: post2, post_action_type_id: PostActionType.types[:bookmark])
    Fabricate(:post_action, user: user3, post: post3, post_action_type_id: PostActionType.types[:bookmark])
  end
end
