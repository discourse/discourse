# frozen_string_literal: true

RSpec.describe Jobs::RefreshCategoryLikeStats do
  fab!(:category)
  fab!(:post)
  fab!(:liker, :user)

  before do
    Jobs.run_immediately!
    UserActionManager.enable
    SiteSetting.enable_user_directory = false
    SiteSetting.exclude_categories_from_like_stats = category.id.to_s
    PostActionCreator.like(liker, post)
  end

  it "recounts likes after a topic changes categories even when the directory is disabled" do
    original_category = post.topic.category
    expect(liker.user_stat.reload.likes_given).to eq(1)

    post.topic.changed_to_category(category)

    expect(liker.user_stat.reload.likes_given).to eq(0)
    expect(post.user.user_stat.reload.likes_received).to eq(0)

    post.topic.changed_to_category(original_category)

    expect(liker.user_stat.reload.likes_given).to eq(1)
    expect(post.user.user_stat.reload.likes_received).to eq(1)
  end

  it "recounts likes after replies move into a topic in an excluded category" do
    moderator = Fabricate(:moderator)
    destination = Fabricate(:post, topic: Fabricate(:topic, category:))
    reply = Fabricate(:post, topic: post.topic, user: post.user)
    PostActionCreator.like(liker, reply)
    expect(liker.user_stat.reload.likes_given).to eq(2)

    PostMover.new(post.topic, moderator, [reply.id]).to_topic(destination.topic_id)

    expect(liker.user_stat.reload.likes_given).to eq(1)
    expect(post.user.user_stat.reload.likes_received).to eq(1)
    expect(reply.reload.like_count).to eq(1)
  end
end
