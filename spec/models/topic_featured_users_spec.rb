# frozen_string_literal: true

RSpec.describe TopicFeaturedUsers do
  it "ensures consistency" do
    t = Fabricate(:topic)
    Fabricate(:post, topic: t, user: t.user)
    p2 = Fabricate(:post, topic: t)
    p3 = Fabricate(:post, topic: t, user: p2.user)
    p4 = Fabricate(:post, topic: t)
    p5 = Fabricate(:post, topic: t)

    t.update_columns(
      featured_user1_id: 66,
      featured_user2_id: 70,
      featured_user3_id: 12,
      featured_user4_id: 7,
      last_post_user_id: p5.user_id,
    )

    TopicFeaturedUsers.ensure_consistency!
    t.reload

    expect(t.featured_user1_id).to eq(p2.user_id)
    expect(t.featured_user2_id).to eq(nil)
    expect(t.featured_user3_id).to eq(p4.user_id)
    expect(t.featured_user4_id).to eq(nil)

    # after removing a post
    p2.update_column(:deleted_at, Time.now)
    p3.update_column(:hidden, true)

    TopicFeaturedUsers.ensure_consistency!
    t.reload

    expect(t.featured_user1_id).to eq(nil)
    expect(t.featured_user2_id).to eq(nil)
    expect(t.featured_user3_id).to eq(p4.user_id)
    expect(t.featured_user4_id).to eq(nil)
  end

  it "keeps a high-count recent poster in a visible featured slot" do
    topic_creator = Fabricate(:user)
    latest_poster = Fabricate(:user)
    frequent_recent_poster = Fabricate(:user)
    frequent_older_poster = Fabricate(:user)
    less_frequent_older_poster = Fabricate(:user)
    recent_poster = Fabricate(:user)
    older_poster = Fabricate(:user)

    topic = Fabricate(:topic, user: topic_creator)
    Fabricate(:post, topic: topic, user: topic_creator, created_at: 7.days.ago)
    Fabricate(:post, topic: topic, user: older_poster, created_at: 6.days.ago)

    4.times do |index|
      Fabricate(
        :post,
        topic: topic,
        user: less_frequent_older_poster,
        created_at: (5.days.ago + index.minutes),
      )
    end

    5.times do |index|
      Fabricate(
        :post,
        topic: topic,
        user: frequent_older_poster,
        created_at: (4.days.ago + index.minutes),
      )
    end

    6.times do |index|
      Fabricate(
        :post,
        topic: topic,
        user: frequent_recent_poster,
        created_at: (2.days.ago + index.minutes),
      )
    end

    Fabricate(:post, topic: topic, user: recent_poster, created_at: 36.hours.ago)
    latest_post = Fabricate(:post, topic: topic, user: latest_poster, created_at: 1.day.ago)
    topic.update_columns(last_post_user_id: latest_post.user_id)

    TopicFeaturedUsers.ensure_consistency!

    expect(topic.reload.featured_user_ids.take(4)).to eq(
      [frequent_recent_poster.id, frequent_older_poster.id, recent_poster.id],
    )
  end

  it "includes the most recent non-OP non-latest poster in a visible featured slot" do
    topic_creator = Fabricate(:user)
    latest_poster = Fabricate(:user)
    frequent_poster1 = Fabricate(:user)
    frequent_poster2 = Fabricate(:user)
    frequent_poster3 = Fabricate(:user)
    recent_poster = Fabricate(:user)

    topic = Fabricate(:topic, user: topic_creator)
    Fabricate(:post, topic: topic, user: topic_creator, created_at: 7.days.ago)

    5.times do |index|
      Fabricate(
        :post,
        topic: topic,
        user: frequent_poster1,
        created_at: (6.days.ago + index.minutes),
      )
    end

    4.times do |index|
      Fabricate(
        :post,
        topic: topic,
        user: frequent_poster2,
        created_at: (5.days.ago + index.minutes),
      )
    end

    3.times do |index|
      Fabricate(
        :post,
        topic: topic,
        user: frequent_poster3,
        created_at: (4.days.ago + index.minutes),
      )
    end

    Fabricate(:post, topic: topic, user: recent_poster, created_at: 2.days.ago)
    latest_post = Fabricate(:post, topic: topic, user: latest_poster, created_at: 1.day.ago)
    topic.update_columns(last_post_user_id: latest_post.user_id)

    TopicFeaturedUsers.ensure_consistency!

    expect(topic.reload.featured_user_ids.take(4)).to eq(
      [frequent_poster1.id, frequent_poster2.id, recent_poster.id],
    )
  end

  it "picks the most recent visible non-OP poster when the latest poster's posts are all hidden" do
    topic_creator = Fabricate(:user)
    ghost_latest_poster = Fabricate(:user)
    recent_visible_poster = Fabricate(:user)
    frequent_poster = Fabricate(:user)

    topic = Fabricate(:topic, user: topic_creator)
    Fabricate(:post, topic: topic, user: topic_creator, created_at: 5.days.ago)

    3.times do |index|
      Fabricate(
        :post,
        topic: topic,
        user: frequent_poster,
        created_at: (4.days.ago + index.minutes),
      )
    end

    Fabricate(:post, topic: topic, user: recent_visible_poster, created_at: 2.days.ago)

    ghost_post = Fabricate(:post, topic: topic, user: ghost_latest_poster, created_at: 1.day.ago)
    topic.update_columns(last_post_user_id: ghost_latest_poster.id)
    ghost_post.update_columns(deleted_at: Time.now)

    TopicFeaturedUsers.ensure_consistency!

    expect(topic.reload.featured_user_ids.take(4)).to eq(
      [frequent_poster.id, recent_visible_poster.id],
    )
  end

  it "puts the recent poster after frequent posters when the OP is the latest poster" do
    topic_creator = Fabricate(:user)
    frequent_poster1 = Fabricate(:user)
    frequent_poster2 = Fabricate(:user)
    frequent_poster3 = Fabricate(:user)
    recent_poster = Fabricate(:user)

    topic = Fabricate(:topic, user: topic_creator)
    Fabricate(:post, topic: topic, user: topic_creator, created_at: 7.days.ago)

    5.times do |index|
      Fabricate(
        :post,
        topic: topic,
        user: frequent_poster1,
        created_at: (6.days.ago + index.minutes),
      )
    end

    4.times do |index|
      Fabricate(
        :post,
        topic: topic,
        user: frequent_poster2,
        created_at: (5.days.ago + index.minutes),
      )
    end

    3.times do |index|
      Fabricate(
        :post,
        topic: topic,
        user: frequent_poster3,
        created_at: (4.days.ago + index.minutes),
      )
    end

    Fabricate(:post, topic: topic, user: recent_poster, created_at: 2.days.ago)
    latest_post = Fabricate(:post, topic: topic, user: topic_creator, created_at: 1.day.ago)
    topic.update_columns(last_post_user_id: latest_post.user_id)

    TopicFeaturedUsers.ensure_consistency!

    expect(topic.reload.featured_user_ids.take(4)).to eq(
      [frequent_poster1.id, frequent_poster2.id, recent_poster.id, frequent_poster3.id],
    )
  end
end
