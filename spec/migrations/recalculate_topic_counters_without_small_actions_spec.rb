# frozen_string_literal: true

require Rails.root.join(
          "db/post_migrate/20260602104726_recalculate_topic_counters_without_small_actions.rb",
        )

RSpec.describe RecalculateTopicCountersWithoutSmallActions do
  subject(:migrate) { described_class.new.up }

  before do
    @verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @verbose }

  fab!(:author, :user)
  fab!(:reader, :user)
  fab!(:topic)

  # Build a posts table that reflects reality, then force the topic + topic_users
  # into the *pre-fix* inflated state (small action counted) so we can assert the
  # migration corrects it.
  def small_action!(post_number)
    Fabricate(:post, topic: topic, user: Discourse.system_user).tap do |p|
      p.update_columns(post_number:, post_type: Post.types[:small_action], raw: "")
    end
  end

  it "recomputes counters and clamps read state for a trailing small action" do
    op = Fabricate(:post, topic: topic, user: author)
    op.update_columns(post_number: 1, post_type: Post.types[:regular])
    small_action!(2)

    topic.update_columns(
      highest_post_number: 2,
      highest_staff_post_number: 2,
      posts_count: 2,
      last_post_user_id: Discourse.system_user.id,
    )
    tracker =
      Fabricate(
        :topic_user,
        topic: topic,
        user: reader,
        last_read_post_number: 2,
        notification_level: TopicUser.notification_levels[:tracking],
      )

    migrate

    topic.reload
    expect(topic.highest_post_number).to eq(1)
    expect(topic.highest_staff_post_number).to eq(1)
    expect(topic.posts_count).to eq(1)
    expect(topic.last_post_user_id).to eq(author.id)
    # last_read pointed at the small action -> clamped back to the real highest.
    expect(tracker.reload.last_read_post_number).to eq(1)
  end

  it "clamps whisperers to highest_staff_post_number and others to highest_post_number" do
    SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
    admin = Fabricate(:admin)

    op = Fabricate(:post, topic: topic, user: author)
    op.update_columns(post_number: 1, post_type: Post.types[:regular])
    whisper = Fabricate(:post, topic: topic, user: admin)
    whisper.update_columns(post_number: 2, post_type: Post.types[:whisper])
    small_action!(3)

    # pre-fix inflated state: small action bumped both counters.
    topic.update_columns(highest_post_number: 3, highest_staff_post_number: 3, posts_count: 2)
    staff_tracker = Fabricate(:topic_user, topic: topic, user: admin, last_read_post_number: 3)
    reader_tracker = Fabricate(:topic_user, topic: topic, user: reader, last_read_post_number: 3)

    migrate

    topic.reload
    expect(topic.highest_post_number).to eq(1) # excludes whisper (2) and small action (3)
    expect(topic.highest_staff_post_number).to eq(2) # excludes small action, keeps whisper

    # whisperer keeps progress against the whisper; regular reader is clamped to public highest.
    expect(staff_tracker.reload.last_read_post_number).to eq(2)
    expect(reader_tracker.reload.last_read_post_number).to eq(1)
  end

  it "is idempotent and leaves already-correct topics untouched" do
    op = Fabricate(:post, topic: topic, user: author)
    op.update_columns(post_number: 1, post_type: Post.types[:regular])
    small_action!(2)
    topic.update_columns(highest_post_number: 1, highest_staff_post_number: 1, posts_count: 1)

    expect { migrate }.not_to raise_error
    migrate # second run is a no-op

    topic.reload
    expect(topic.highest_post_number).to eq(1)
    expect(topic.posts_count).to eq(1)
  end
end
