# frozen_string_literal: true

describe "Boards sync when a topic is recovered" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  before { enable_current_plugin }

  it "syncs the topic once when staff recover a deleted topic" do
    first_post = create_post(user: user)
    PostDestroyer.new(admin, first_post).destroy

    Boards::TopicSync.expects(:sync_topic).with(first_post.topic).once

    PostDestroyer.new(admin, first_post.reload).recover
  end

  it "syncs the topic when authors cancel their own topic deletion" do
    first_post = create_post(user: user)
    PostDestroyer.new(user, first_post).destroy

    Boards::TopicSync.expects(:sync_topic).with(first_post.topic).once

    PostDestroyer.new(user, first_post.reload).recover
  end
end
