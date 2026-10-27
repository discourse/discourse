# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::SetSlowMode::V1 do
  fab!(:moderator)
  fab!(:user)
  fab!(:topic, :topic_with_op)

  before { freeze_time }

  def set_slow_mode(**configuration)
    execute_node(configuration: { "topic_id" => topic.id.to_s, **configuration.stringify_keys })
  end

  describe "#execute" do
    it "sets the interval until a time in the given timezone, as the actor", :aggregate_failures do
      result = nil
      events =
        DiscourseEvent.track_events(:topic_slow_mode_set) do
          result =
            set_slow_mode(
              interval: 30,
              interval_unit: "minutes",
              enabled_until: "2030-01-15 09:00",
              timezone: "Europe/Paris",
              actor_username: moderator.username,
            )
        end

      expect(topic.reload.slow_mode_seconds).to eq(1800)
      expect(topic.slow_mode_topic_timer.execute_at).to eq_time(Time.utc(2030, 1, 15, 8))
      expect(result).to include(
        "changed" => true,
        "slow_mode_seconds" => 1800,
        "slow_mode_enabled_until" => "2030-01-15T08:00:00Z",
        "topic" => include("id" => topic.id),
      )
      expect(result).to match_node_output_schema(described_class)
      expect(events.map { |event| event[:params].last }).to eq([{ acting_user: moderator }])
    end

    it "reports nothing changed when slow mode is already set that way" do
      configuration = { interval: 1, interval_unit: "hours", enabled_until: "2030-01-15 09:00" }

      first = set_slow_mode(**configuration)
      second = set_slow_mode(**configuration)

      expect(first).to include("changed" => true, "slow_mode_seconds" => 3600)
      expect(second).to include("changed" => false, "slow_mode_seconds" => 3600)
    end

    it "removes an end time set earlier when none is given" do
      set_slow_mode(interval: 1, interval_unit: "hours", enabled_until: "2030-01-15 09:00")

      result = set_slow_mode(interval: 1, interval_unit: "hours")

      expect(topic.reload.slow_mode_topic_timer).to be_nil
      expect(result).to include("changed" => true, "slow_mode_enabled_until" => nil)
    end

    it "rejects an actor who can't moderate the topic" do
      expect { set_slow_mode(actor_username: user.username) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /#{Regexp.escape(I18n.t("discourse_workflows.errors.topic_slow_mode.not_allowed", username: user.username, topic_id: topic.id))}/,
      )

      expect(topic.reload.slow_mode_seconds).to eq(0)
    end

    it "rejects intervals outside of 1 second to a year" do
      expect { set_slow_mode(interval: 0) }.to raise_error(DiscourseWorkflows::NodeError)
      expect { set_slow_mode(interval: 400, interval_unit: "days") }.to raise_error(
        DiscourseWorkflows::NodeError,
      )
      expect { set_slow_mode(interval_unit: "weeks") }.to raise_error(DiscourseWorkflows::NodeError)
      expect(topic.reload.slow_mode_seconds).to eq(0)
    end

    it "rejects an end time in the past" do
      expect { set_slow_mode(enabled_until: "2020-01-01 09:00") }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Slow mode could not be changed/,
      )

      expect(topic.reload.slow_mode_seconds).to eq(0)
    end
  end

  describe ".validate_configuration" do
    def errors_for(configuration)
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(configuration, errors)
      errors.map(&:message)
    end

    it "rejects invalid intervals, units and timezones" do
      expect(errors_for("interval" => 0)).to be_present
      expect(errors_for("interval" => 400, "interval_unit" => "days")).to be_present
      expect(errors_for("interval_unit" => "weeks")).to be_present
      expect(errors_for("timezone" => "Mars/Olympus")).to be_present
    end

    it "accepts valid and expression values" do
      expect(errors_for("interval" => 2, "interval_unit" => "hours")).to be_empty
      expect(
        errors_for("interval" => "={{ $json.seconds }}", "interval_unit" => "seconds"),
      ).to be_empty
    end
  end
end

RSpec.describe DiscourseWorkflows::Nodes::ClearSlowMode::V1 do
  fab!(:topic) { Fabricate(:topic_with_op, slow_mode_seconds: 600) }

  it "clears slow mode and its end time, and reports nothing changed the second time",
     :aggregate_failures do
    Topic::UpdateSlowMode.call(
      guardian: Discourse.system_user.guardian,
      params: {
        topic_id: topic.id,
        seconds: 600,
        enabled_until: "24",
      },
    )

    first = execute_node(configuration: { "topic_id" => topic.id.to_s })
    second = execute_node(configuration: { "topic_id" => topic.id.to_s })

    expect(topic.reload).to have_attributes(slow_mode_seconds: 0, slow_mode_topic_timer: nil)
    expect(first).to include("changed" => true, "topic" => include("id" => topic.id))
    expect(first).to match_node_output_schema(described_class)
    expect(second).to include("changed" => false)
  end
end
