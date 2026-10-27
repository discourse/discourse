# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::SetTopicTimer::V1 do
  fab!(:moderator)
  fab!(:user)
  fab!(:trust_level_4)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic_with_op, category: category) }

  before { freeze_time }

  def set_timer(**configuration)
    execute_node(configuration: { "topic_id" => topic.id.to_s, **configuration.stringify_keys })
  end

  def timer_events(&)
    DiscourseEvent.track_events(:topic_timer_changed, &)
  end

  describe "#execute" do
    it "schedules a timer at a time in the given timezone, as the actor", :aggregate_failures do
      result = nil
      events =
        timer_events do
          result =
            set_timer(
              schedule: "at_time",
              execute_at: "2030-01-15 09:00",
              timezone: "Europe/Paris",
              actor_username: moderator.username,
            )
        end

      timer = topic.public_topic_timer
      expect(timer).to have_attributes(status_type: TopicTimer.types[:close], user: moderator)
      expect(timer.execute_at).to eq_time(Time.utc(2030, 1, 15, 8))
      expect(result).to include(
        "changed" => true,
        "topic" => include("id" => topic.id),
        "timer" => include("id" => timer.id, "status_type" => "close", "user_id" => moderator.id),
      )
      expect(result).to match_node_output_schema(described_class)
      expect(events.map { |event| event[:params].values_at(1, -1) }).to eq(
        [[:created, { acting_user: moderator }]],
      )
    end

    it "schedules a timer after a duration" do
      set_timer(timer_type: "open", duration: 3, duration_unit: "hours")

      expect(topic.public_topic_timer).to have_attributes(
        status_type: TopicTimer.types[:open],
        execute_at: eq_time(3.hours.from_now),
      )
    end

    it "schedules a close timer after the last post" do
      last_post = Fabricate(:post, topic: topic, created_at: 1.hour.ago)

      set_timer(schedule: "after_last_post", duration: 90, duration_unit: "minutes")

      expect(topic.public_topic_timer).to have_attributes(
        based_on_last_post: true,
        duration_minutes: 90,
        execute_at: eq_time(last_post.created_at + 90.minutes),
      )
    end

    it "deletes replies older than the duration" do
      set_timer(timer_type: "delete_replies", duration: 2, duration_unit: "days")

      expect(topic.public_topic_timer).to have_attributes(
        status_type: TopicTimer.types[:delete_replies],
        duration_minutes: 2.days.in_minutes.to_i,
      )
    end

    it "reports nothing changed when the topic already has the same timer" do
      configuration = { schedule: "at_time", execute_at: "2030-01-15 09:00", timezone: "UTC" }
      set_timer(**configuration)
      result = nil

      events = timer_events { result = set_timer(**configuration) }

      expect(result).to include("changed" => false)
      expect(events).to be_empty
    end

    it "replaces the topic's timer with one of another type" do
      set_timer(duration: 1)

      result = set_timer(timer_type: "bump", duration: 2)

      expect(topic.topic_timers.where(public_type: true).sole.status_type).to eq(
        TopicTimer.types[:bump],
      )
      expect(result).to include("changed" => true, "timer" => include("status_type" => "bump"))
    end

    it "opens a closed topic now when setting a close timer, like Open temporarily" do
      topic.update_status("closed", true, moderator)

      result = set_timer(duration: 1)

      expect(result["topic"]).to include("closed" => false)
    end

    it "publishes to a category the actor can create topics in" do
      destination = Fabricate(:category)

      result =
        set_timer(timer_type: "publish_to_category", duration: 1, category_id: destination.id)

      expect(result["timer"]).to include("category_id" => destination.id)
    end

    it "rejects a publication timer without an existing category" do
      expect { set_timer(timer_type: "publish_to_category", duration: 1) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /needs a category/,
      )
      expect {
        set_timer(timer_type: "publish_to_category", duration: 1, category_id: -1)
      }.to raise_error(DiscourseWorkflows::NodeError, /doesn't exist/)
    end

    it "rejects invalid schedules without touching the existing timer", :aggregate_failures do
      timer = topic.set_or_create_timer(TopicTimer.types[:close], 5, by_user: moderator)
      max_days = BaseTimer::MAX_DURATION_MINUTES / 1.day.in_minutes.to_i

      [
        { schedule: "at_time", execute_at: 1.hour.ago.iso8601, timezone: "UTC" },
        { schedule: "at_time", execute_at: "not a date" },
        { schedule: "at_time" },
        { schedule: "at_time", timer_type: "delete_replies", execute_at: "2030-01-15 09:00" },
        { schedule: "after_last_post", timer_type: "bump" },
        { duration: 0 },
        { duration: "soon" },
        { duration: max_days + 1, duration_unit: "days" },
        { schedule: "never" },
        { duration_unit: "weeks" },
        { timer_type: "reminder" },
      ].each do |configuration|
        expect { set_timer(**configuration) }.to raise_error(DiscourseWorkflows::NodeError)
      end

      expect(topic.public_topic_timer).to have_attributes(
        id: timer.id,
        execute_at: eq_time(5.hours.from_now),
      )
    end

    it "rejects an unknown schedule given by an expression" do
      expect {
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
            "schedule" => "={{ $json.schedule }}",
          },
          item: {
            "json" => {
              "schedule" => "tomorrow",
            },
          },
        )
      }.to raise_error(DiscourseWorkflows::NodeError, /Unknown schedule: tomorrow/)
    end

    it "rejects actors who can't set the timer", :aggregate_failures do
      expect { set_timer(duration: 1, actor_username: user.username) }.to raise_error(
        Discourse::InvalidAccess,
      )
      expect { set_timer(duration: 1, actor_username: "anonymous") }.to raise_error(
        Discourse::InvalidAccess,
      )
      expect {
        set_timer(timer_type: "delete", duration: 1, actor_username: trust_level_4.username)
      }.to raise_error(Discourse::InvalidAccess)

      expect(topic.topic_timers).to be_empty
    end
  end

  describe ".validate_configuration" do
    def errors_for(configuration)
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(configuration, errors)
      errors.map(&:message)
    end

    it "rejects schedules the timer type can't use" do
      expect(errors_for("timer_type" => "bump", "schedule" => "after_last_post")).to be_present
      expect(errors_for("timer_type" => "delete_replies", "schedule" => "at_time")).to be_present
      expect(errors_for("timezone" => "Mars/Olympus")).to be_present
    end

    it "accepts valid and expression values" do
      expect(errors_for("timer_type" => "close", "schedule" => "after_last_post")).to be_empty
      expect(errors_for("timer_type" => "={{ $json.type }}", "schedule" => "at_time")).to be_empty
    end
  end

  # The topics controller's timer endpoint and this node must refuse the same actors.
  describe "permission parity with the topics controller", type: :request do
    fab!(:destination) { Fabricate(:private_category, group: Fabricate(:group)) }
    fab!(:personal_message) { Fabricate(:private_message_topic, user: trust_level_4) }

    it "refuses whatever the controller refuses", :aggregate_failures do
      [
        [user, topic, { status_type: "close", time: 24 }],
        [trust_level_4, topic, { status_type: "delete", time: 24 }],
        [trust_level_4, topic, { status_type: "delete_replies", duration_minutes: 60 }],
        [
          trust_level_4,
          topic,
          { status_type: "publish_to_category", time: 24, category_id: destination.id },
        ],
        [
          trust_level_4,
          personal_message,
          { status_type: "publish_to_category", time: 24, category_id: category.id },
        ],
      ].each do |actor, target, params|
        sign_in(actor)
        post "/t/#{target.id}/timer.json", params: params
        expect(response.status).to eq(403)

        configuration = {
          "topic_id" => target.id.to_s,
          "timer_type" => params[:status_type],
          "duration" => 1,
          "category_id" => params[:category_id],
          "actor_username" => actor.username,
        }
        expect { execute_node(configuration:) }.to raise_error(Discourse::InvalidAccess)
      end
    end
  end
end

RSpec.describe DiscourseWorkflows::Nodes::ClearTopicTimer::V1 do
  fab!(:moderator)
  fab!(:user)
  fab!(:trust_level_4)
  fab!(:topic, :topic_with_op)

  def clear_timer(**configuration)
    execute_node(configuration: { "topic_id" => topic.id.to_s, **configuration.stringify_keys })
  end

  it "cancels the topic's timer of that type, as the actor", :aggregate_failures do
    timer = topic.set_or_create_timer(TopicTimer.types[:close], 5, by_user: moderator)
    result = nil

    events =
      DiscourseEvent.track_events(:topic_timer_changed) do
        result = clear_timer(actor_username: moderator.username)
      end

    expect(timer.reload).to be_trashed
    expect(result).to include("changed" => true, "timer" => include("id" => timer.id))
    expect(result).to match_node_output_schema(described_class)
    expect(events.map { |event| event[:params].values_at(1, -1) }).to eq(
      [[:cancelled, { acting_user: moderator }]],
    )
  end

  it "reports nothing changed and leaves other timers alone without a timer of that type" do
    bump = topic.set_or_create_timer(TopicTimer.types[:bump], 5, by_user: moderator)

    result = clear_timer(timer_type: "close")

    expect(result).to include("changed" => false, "timer" => nil)
    expect(result).to match_node_output_schema(described_class)
    expect(topic.public_topic_timer).to eq(bump)
  end

  it "reports nothing changed when a concurrent request cleared the timer first",
     :aggregate_failures do
    timer = topic.set_or_create_timer(TopicTimer.types[:close], 5, by_user: moderator)
    TopicTimer.any_instance.stubs(:finish!).returns(false)

    result = clear_timer(actor_username: moderator.username)

    expect(result).to include("changed" => false, "timer" => include("id" => timer.id))
    expect(result).to match_node_output_schema(described_class)
  end

  it "clears a publication timer on a personal message without checking the category" do
    personal_message = Fabricate(:private_message_topic, user: trust_level_4)
    timer =
      Fabricate(
        :topic_timer,
        topic: personal_message,
        user: moderator,
        category: Fabricate(:private_category, group: Fabricate(:group)),
        status_type: TopicTimer.types[:publish_to_category],
      )

    result =
      execute_node(
        configuration: {
          "topic_id" => personal_message.id.to_s,
          "timer_type" => "publish_to_category",
          "actor_username" => trust_level_4.username,
        },
      )

    expect(result).to include("changed" => true)
    expect(timer.reload).to be_trashed
  end

  it "rejects actors who can't clear the timer", :aggregate_failures do
    topic.set_or_create_timer(TopicTimer.types[:delete], 5, by_user: moderator)

    expect { clear_timer(timer_type: "delete", actor_username: user.username) }.to raise_error(
      Discourse::InvalidAccess,
    )
    expect {
      clear_timer(timer_type: "delete", actor_username: trust_level_4.username)
    }.to raise_error(Discourse::InvalidAccess)

    expect(topic.reload.public_topic_timer).to be_present
  end
end
