# frozen_string_literal: true

require Rails.root.join(
          "db/post_migrate/20260403110200_exclude_small_action_posts_from_topic_stats.rb",
        )

describe ExcludeSmallActionPostsFromTopicStats do
  fab!(:user)

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def stat_columns_for(topic)
    DB.query_single(<<~SQL, id: topic.id).first
      SELECT array[
        highest_post_number::text,
        posts_count::text,
        word_count::text,
        last_post_user_id::text
      ]
      FROM topics WHERE id = :id
    SQL
  end

  it "excludes unedited (version = 1) small action posts from topic stats" do
    topic = Fabricate(:topic)
    p1 = Fabricate(:post, topic: topic, user: user, post_number: 1)
    small =
      Fabricate(
        :post,
        topic: topic,
        post_number: 2,
        post_type: Post.types[:small_action],
        raw: "Closed automatically.",
        version: 1,
      )
    topic.update_columns(
      highest_post_number: 2,
      posts_count: 2,
      last_posted_at: small.created_at,
      last_post_user_id: small.user_id,
      word_count: 100,
    )

    described_class.new.up

    topic.reload
    expect(topic.highest_post_number).to eq(1)
    expect(topic.posts_count).to eq(1)
    expect(topic.last_post_user_id).to eq(p1.user_id)
  end

  it "excludes content-less small action posts from topic stats" do
    topic = Fabricate(:topic)
    Fabricate(:post, topic: topic, user: user, post_number: 1)
    small =
      Fabricate(
        :post,
        topic: topic,
        post_number: 2,
        post_type: Post.types[:small_action],
        version: 5,
      )
    small.update_columns(raw: "")
    topic.update_columns(highest_post_number: 2, posts_count: 2)

    described_class.new.up

    topic.reload
    expect(topic.highest_post_number).to eq(1)
    expect(topic.posts_count).to eq(1)
  end

  it "keeps user-edited (version > 1, raw present) small actions in stats" do
    topic = Fabricate(:topic)
    Fabricate(:post, topic: topic, user: user, post_number: 1)
    Fabricate(
      :post,
      topic: topic,
      post_number: 2,
      post_type: Post.types[:small_action],
      raw: "Admin note explaining the closure.",
      version: 2,
    )
    topic.update_columns(highest_post_number: 0, posts_count: 0)

    described_class.new.up

    topic.reload
    expect(topic.highest_post_number).to eq(2)
    expect(topic.posts_count).to eq(2)
  end

  it "leaves private message topics untouched" do
    pm = Fabricate(:private_message_topic)
    Fabricate(:post, topic: pm, post_number: 1)
    Fabricate(:post, topic: pm, post_number: 2, post_type: Post.types[:small_action])
    pm.update_columns(highest_post_number: 999, posts_count: 999)

    described_class.new.up

    expect(pm.reload.highest_post_number).to eq(999)
    expect(pm.reload.posts_count).to eq(999)
  end

  it "clamps topic_users.last_read_post_number that exceed the new highest_post_number" do
    topic = Fabricate(:topic)
    Fabricate(:post, topic: topic, user: user, post_number: 1)
    Fabricate(:post, topic: topic, post_number: 2, post_type: Post.types[:small_action])
    topic.update_columns(highest_post_number: 2, posts_count: 2)
    TopicUser.create!(user: Fabricate(:user), topic: topic, last_read_post_number: 2)

    described_class.new.up

    expect(TopicUser.where(topic: topic).pluck(:last_read_post_number)).to all(eq(1))
  end
end
