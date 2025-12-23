# frozen_string_literal: true

describe "SetTopicTimer" do
  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scripts::SET_TOPIC_TIMER,
      trigger: DiscourseAutomation::Triggers::POST_CREATED_EDITED,
    )
  end

  def configure_automation(type, duration)
    automation.fields.create!(
      component: "choices",
      name: "type",
      metadata: {
        value: type,
      },
      target: "script",
    )
    automation.fields.create!(
      component: "relative_time",
      name: "duration",
      metadata: {
        value: duration,
      },
      target: "script",
    )
  end

  before { SiteSetting.discourse_automation_enabled = true }

  it "handles auto_close timer" do
    configure_automation("auto_close", 60)

    freeze_time do
      post =
        PostCreator.new(
          Fabricate(:admin),
          raw: "my new topic",
          title: "Test topic for timer",
        ).create!

      timer = post.topic.reload.topic_timers[0]
      expect(timer.status_type).to eq(TopicTimer.types[:close])
      expect(timer.execute_at).to be_within(1.second).of(60.minutes.from_now)
      expect(timer.based_on_last_post).to eq(false)
    end
  end

  it "handles auto_close_after_last_post timer" do
    configure_automation("auto_close_after_last_post", 60)

    freeze_time do
      post =
        PostCreator.new(
          Fabricate(:admin),
          raw: "my new topic",
          title: "Test topic for timer",
        ).create!

      timer = post.topic.reload.topic_timers[0]
      expect(timer.status_type).to eq(TopicTimer.types[:close])
      expect(timer.execute_at).to be_within(1.second).of(60.minutes.from_now)
      expect(timer.duration_minutes).to eq(60)
      expect(timer.based_on_last_post).to eq(true)
    end
  end

  it "handles auto_delete timer" do
    configure_automation("auto_delete", 60)

    freeze_time do
      post =
        PostCreator.new(
          Fabricate(:admin),
          raw: "my new topic",
          title: "Test topic for timer",
        ).create!

      timer = post.topic.reload.topic_timers[0]
      expect(timer.status_type).to eq(TopicTimer.types[:delete])
      expect(timer.execute_at).to be_within(1.second).of(60.minutes.from_now)
      expect(timer.duration_minutes).to eq(nil)
      expect(timer.based_on_last_post).to eq(false)
    end
  end

  it "handles auto_delete_replies timer" do
    configure_automation("auto_delete_replies", 60)

    freeze_time do
      post =
        PostCreator.new(
          Fabricate(:admin),
          raw: "my new topic",
          title: "Test topic for timer",
        ).create!

      timer = post.topic.reload.topic_timers[0]
      expect(timer.status_type).to eq(TopicTimer.types[:delete_replies])
      expect(timer.execute_at).to be_within(1.second).of(60.minutes.from_now)
      expect(timer.duration_minutes).to eq(60)
      expect(timer.based_on_last_post).to eq(false)
    end
  end

  it "handles auto_bump timer" do
    configure_automation("auto_bump", 60)

    freeze_time do
      post =
        PostCreator.new(
          Fabricate(:admin),
          raw: "my new topic",
          title: "Test topic for timer",
        ).create!

      timer = post.topic.reload.topic_timers[0]
      expect(timer.status_type).to eq(TopicTimer.types[:bump])
      expect(timer.execute_at).to be_within(1.second).of(60.minutes.from_now)
      expect(timer.duration_minutes).to eq(nil)
      expect(timer.based_on_last_post).to eq(false)
    end
  end
end
