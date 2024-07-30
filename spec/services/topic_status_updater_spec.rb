# encoding: UTF-8
# frozen_string_literal: true

# TODO - test pinning, create_moderator_post

RSpec.describe TopicStatusUpdater do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)

  it "avoids notifying on automatically closed topics" do
    # TODO: TopicStatusUpdater should suppress message bus updates from the users it "pretends to read"
    post =
      PostCreator.create(
        user,
        raw: "this is a test post 123 this is a test post",
        title: "hello world title",
      )
    # TODO needed so counts sync up, PostCreator really should not give back out-of-date Topic
    post.topic.set_or_create_timer(TopicTimer.types[:close], "10")
    post.topic.reload

    TopicStatusUpdater.new(post.topic, admin).update!("autoclosed", true)

    expect(post.topic.posts.count).to eq(2)

    tu = TopicUser.find_by(user_id: user.id)
    expect(tu.last_read_post_number).to eq(2)
  end

  it "adds an autoclosed message" do
    topic = create_topic
    topic.set_or_create_timer(TopicTimer.types[:close], "10")

    TopicStatusUpdater.new(topic, admin).update!("autoclosed", true)

    last_post = topic.posts.last
    expect(last_post.post_type).to eq(Post.types[:small_action])
    expect(last_post.action_code).to eq("autoclosed.enabled")
    expect(last_post.raw).to eq(I18n.t("topic_statuses.autoclosed_enabled_minutes", count: 0))
  end

  it "triggers a DiscourseEvent on close" do
    topic = create_topic

    called = false
    updater = ->(_) { called = true }

    DiscourseEvent.on(:topic_closed, &updater)
    TopicStatusUpdater.new(topic, admin).update!("closed", true)
    DiscourseEvent.off(:topic_closed, &updater)

    expect(topic).to be_closed
    expect(called).to eq(true)
  end

  it "adds an autoclosed message based on last post" do
    topic = create_topic
    Fabricate(:post, topic: topic)

    topic.set_or_create_timer(
      TopicTimer.types[:close],
      nil,
      based_on_last_post: true,
      duration_minutes: 600,
    )

    TopicStatusUpdater.new(topic, admin).update!("autoclosed", true)

    last_post = topic.posts.last
    expect(last_post.post_type).to eq(Post.types[:small_action])
    expect(last_post.action_code).to eq("autoclosed.enabled")
    expect(last_post.raw).to eq(
      I18n.t("topic_statuses.autoclosed_enabled_lastpost_hours", count: 10),
    )
  end

  describe "opening the topic" do
    it "opens the topic and deletes the timer" do
      topic = create_topic

      topic.set_or_create_timer(TopicTimer.types[:open], 10.hours.from_now)

      TopicStatusUpdater.new(topic, admin).update!("closed", false)
      timer = TopicTimer.find_by(topic: topic)
      expect(timer).to eq(nil)
    end

    context "when the category has auto close settings" do
      let(:topic) { create_topic }
      let(:based_on_last_post) { false }

      before do
        # auto close after 3 days, topic was created a day ago
        topic.update(
          category:
            Fabricate(
              :category,
              auto_close_hours: 72,
              auto_close_based_on_last_post: based_on_last_post,
            ),
          created_at: 1.day.ago,
        )
      end

      it "inherits auto close from the topic category, based on the created_at date of the topic" do
        # close the topic manually, and set a timer to automatically open
        TopicStatusUpdater.new(topic, admin).update!("closed", true)
        topic.set_or_create_timer(TopicTimer.types[:open], 10.hours.from_now)

        # manually open the topic. it has been 1 days since creation so the
        # topic should auto-close 2 days from now, the original auto close time
        TopicStatusUpdater.new(topic, admin).update!("closed", false)

        timer = TopicTimer.find_by(topic: topic)
        expect(timer).not_to eq(nil)
        expect(timer.execute_at).to be_within_one_second_of(topic.created_at + 72.hours)
      end

      it "does not inherit auto close from the topic category if it has already been X hours since topic creation" do
        topic.category.update(auto_close_hours: 1)

        # close the topic manually, and set a timer to automatically open
        TopicStatusUpdater.new(topic, admin).update!("closed", true)
        topic.set_or_create_timer(TopicTimer.types[:open], 10.hours.from_now)

        # manually open the topic. it has been over a day since creation and
        # the auto close hours was 1 so a new timer should not be made
        TopicStatusUpdater.new(topic, admin).update!("closed", false)

        timer = TopicTimer.find_by(topic: topic)
        expect(timer).to eq(nil)
      end

      context "when category setting is based_on_last_post" do
        let(:based_on_last_post) { true }

        it "inherits auto close from the topic category, using the duration because the close is based_on_last_post" do
          # close the topic manually, and set a timer to automatically open
          TopicStatusUpdater.new(topic, admin).update!("closed", true)
          topic.set_or_create_timer(TopicTimer.types[:open], 10.hours.from_now)

          # manually open the topic. it should re open 3 days from now, NOT
          # 3 days from creation
          TopicStatusUpdater.new(topic, admin).update!("closed", false)

          timer = TopicTimer.find_by(topic: topic)
          expect(timer).not_to eq(nil)
          expect(timer.duration_minutes).to eq(72 * 60)
          expect(timer.execute_at).to be_within_one_second_of(Time.zone.now + 72.hours)
        end
      end
    end
  end

  describe "repeat actions" do
    shared_examples "an action that doesn't repeat" do
      it "does not perform the update twice" do
        topic = Fabricate(:topic, status_name => false)
        updated = TopicStatusUpdater.new(topic, admin).update!(status_name, true)
        expect(updated).to eq(true)
        expect(topic.public_send("#{status_name}?")).to eq(true)

        updated = TopicStatusUpdater.new(topic, admin).update!(status_name, true)
        expect(updated).to eq(false)
        expect(topic.posts.where(post_type: Post.types[:small_action]).count).to eq(1)

        updated = TopicStatusUpdater.new(topic, admin).update!(status_name, false)
        expect(updated).to eq(true)
        expect(topic.public_send("#{status_name}?")).to eq(false)

        updated = TopicStatusUpdater.new(topic, admin).update!(status_name, false)
        expect(updated).to eq(false)
        expect(topic.posts.where(post_type: Post.types[:small_action]).count).to eq(2)
      end
    end

    it_behaves_like "an action that doesn't repeat" do
      let(:status_name) { "closed" }
    end

    it_behaves_like "an action that doesn't repeat" do
      let(:status_name) { "visible" }
    end

    it_behaves_like "an action that doesn't repeat" do
      let(:status_name) { "archived" }
    end

    it "updates autoclosed" do
      topic = Fabricate(:topic)
      updated = TopicStatusUpdater.new(topic, admin).update!("autoclosed", true)
      expect(updated).to eq(true)
      expect(topic.closed?).to eq(true)

      updated = TopicStatusUpdater.new(topic, admin).update!("autoclosed", true)
      expect(updated).to eq(false)
      expect(topic.posts.where(post_type: Post.types[:small_action]).count).to eq(1)

      updated = TopicStatusUpdater.new(topic, admin).update!("autoclosed", false)
      expect(updated).to eq(true)
      expect(topic.closed?).to eq(false)

      updated = TopicStatusUpdater.new(topic, admin).update!("autoclosed", false)
      expect(updated).to eq(false)
      expect(topic.posts.where(post_type: Post.types[:small_action]).count).to eq(2)
    end

    it "sets visibility_reason_id" do
      topic = Fabricate(:topic)

      updated = TopicStatusUpdater.new(topic, admin).update!("visible", false)
      expect(updated).to eq(true)
      expect(topic.visible).to eq(false)
      expect(topic.visibility_reason_id).to eq(Topic.visibility_reasons[:unknown])

      updated =
        TopicStatusUpdater.new(topic, admin).update!(
          "visible",
          true,
          { visibility_reason_id: Topic.visibility_reasons[:manually_relisted] },
        )
      expect(updated).to eq(true)
      expect(topic.visible).to eq(true)
      expect(topic.visibility_reason_id).to eq(Topic.visibility_reasons[:manually_relisted])
    end
  end
end
