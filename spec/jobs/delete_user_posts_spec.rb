# frozen_string_literal: true

RSpec.describe Jobs::DeleteUserPosts do
  fab!(:admin)
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:posts) { Fabricate.times(3, :post, user: user, topic: topic) }

  it "deletes all posts for the user in batches" do
    expect(user.posts.count).to eq(3)
    described_class.new.execute(user_id: user.id, acting_user_id: admin.id)
    user.reload
    expect(user.post_count).to eq(0)
    expect(topic.reload.posts.count).to eq(0)
  end

  it "sends a system message with deletion count and invites admins" do
    described_class.new.execute(user_id: user.id, acting_user_id: admin.id)
    system_message = Post.where(user: Discourse.system_user).last
    expect(system_message).to be_present
    expect(system_message.topic.allowed_groups).to include(Group[:admins])
  end

  it "does nothing if not authorized to delete posts" do
    non_admin = Fabricate(:user)
    expect {
      described_class.new.execute(user_id: user.id, acting_user_id: non_admin.id)
    }.not_to change { user.posts.count }

    allow_any_instance_of(Guardian).to receive(:can_delete_all_posts?).and_return(false)
    expect {
      described_class.new.execute(user_id: user.id, acting_user_id: admin.id)
    }.not_to change { user.posts.count }
  end

  it "does nothing if user has no posts" do
    user.posts.destroy_all
    user.reload
    expect {
      described_class.new.execute(user_id: user.id, acting_user_id: admin.id)
    }.not_to change { user.posts.count }
  end

  it "handles large post counts by batching" do
    Fabricate.times(7, :post, user: user, topic: topic)
    expect(user.posts.count).to eq(10)
    described_class.new.execute(user_id: user.id, acting_user_id: admin.id)
    user.reload
    expect(user.posts.count).to eq(0)
  end
end
