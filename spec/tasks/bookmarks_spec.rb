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

  def invoke_task(args = nil)
    capture_stdout do
      Rake::Task['bookmarks:sync_to_table'].invoke(args)
    end
  end

  it "migrates all PostActions" do
    invoke_task

    expect(Bookmark.all.count).to eq(3)
  end

  it "does not create bookmarks that already exist in the bookmarks table for a user" do
    Fabricate(:bookmark, user: user1, post: post1)

    invoke_task

    expect(Bookmark.all.count).to eq(3)
    expect(Bookmark.where(post: post1, user: user1).count).to eq(1)
  end

  it "skips post actions where the post topic no longer exists and does not error" do
    post1.topic.delete
    post1.reload
    expect { invoke_task }.not_to raise_error
  end

  it "skips post actions where the post no longer exists and does not error" do
    post1.delete
    expect { invoke_task }.not_to raise_error
  end

  def create_post_actions_and_existing_bookmarks
    Fabricate(:post_action, user: user1, post: post1, post_action_type_id: PostActionType.types[:bookmark])
    Fabricate(:post_action, user: user2, post: post2, post_action_type_id: PostActionType.types[:bookmark])
    Fabricate(:post_action, user: user3, post: post3, post_action_type_id: PostActionType.types[:bookmark])
  end
end
