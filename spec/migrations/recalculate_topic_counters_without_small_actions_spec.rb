# frozen_string_literal: true

require Rails.root.join(
          "db/post_migrate/20260526045813_recalculate_topic_counters_without_small_actions.rb",
        )

RSpec.describe RecalculateTopicCountersWithoutSmallActions do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "recalculates counters without small actions" do
    SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
    DB.exec(<<~SQL, value: Group::AUTO_GROUPS[:staff].to_s, now: Time.zone.now)
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES ('whispers_allowed_groups', 20, :value, :now, :now)
      ON CONFLICT (name) DO UPDATE SET value = :value, updated_at = :now
    SQL
    user = Fabricate(:admin)
    moderator = Fabricate(:moderator)
    reader = Fabricate(:user)
    post = create_post(user: user)
    topic = post.topic
    whisper = create_post(topic: topic, user: moderator, post_type: Post.types[:whisper])
    small_action = topic.add_small_action(moderator, "closed.enabled")

    topic.update!(
      highest_post_number: small_action.post_number,
      highest_staff_post_number: small_action.post_number,
      posts_count: 3,
      last_posted_at: small_action.created_at,
      last_post_user_id: small_action.user_id,
      word_count: 999,
    )
    [user, reader].each do |topic_user|
      TopicUser.change(
        topic_user.id,
        topic.id,
        last_read_post_number: small_action.post_number,
        notification_level: TopicUser.notification_levels[:tracking],
      )
    end

    described_class.new.up

    topic.reload
    admin_topic_user = TopicUser.find_by!(topic: topic, user: user)
    reader_topic_user = TopicUser.find_by!(topic: topic, user: reader)
    expect(topic.highest_post_number).to eq(post.post_number)
    expect(topic.highest_staff_post_number).to eq(whisper.post_number)
    expect(topic.posts_count).to eq(1)
    expect(topic.last_posted_at).to eq_time(post.created_at)
    expect(topic.last_post_user_id).to eq(post.user_id)
    expect(topic.word_count).to eq(post.word_count)
    expect(admin_topic_user.last_read_post_number).to eq(whisper.post_number)
    expect(reader_topic_user.last_read_post_number).to eq(post.post_number)
  end
end
