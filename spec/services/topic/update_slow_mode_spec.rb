# frozen_string_literal: true

RSpec.describe Topic::UpdateSlowMode do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(topic_id: 1, seconds:, enabled_until:) }

    let(:seconds) { 3600 }
    let(:enabled_until) { nil }

    before { freeze_time(Time.utc(2026, 1, 1, 12)) }

    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:seconds) }
    it { is_expected.to allow_values(0, 1.year.to_i).for(:seconds) }
    it { is_expected.not_to allow_values(-1, 1.year.to_i + 1).for(:seconds) }
    it { is_expected.to allow_values("2026-01-02 12:00", "24").for(:enabled_until) }

    it do
      is_expected.not_to allow_values("2025-12-31 12:00", "-1", "garbage", "2030-13-45 09:00").for(
        :enabled_until,
      )
    end

    it "reads a number of hours from now" do
      contract = described_class.new(seconds: 60, enabled_until: "2")
      contract.validate

      expect(contract.ends_at).to eq_time(Time.utc(2026, 1, 1, 14))
    end

    it "reads a date and time as UTC" do
      contract = described_class.new(seconds: 60, enabled_until: "2030-01-15 09:00")
      contract.validate

      expect(contract.ends_at).to eq_time(Time.utc(2030, 1, 15, 9))
    end

    context "when slow mode is turned off" do
      let(:seconds) { 0 }
      let(:enabled_until) { "2025-12-31 12:00" }

      it "ignores the end time" do
        expect(contract).to be_valid
        expect(contract.ends_at).to be_nil
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:moderator)
    fab!(:other_moderator, :moderator)
    fab!(:topic)

    let(:params) { { topic_id:, seconds:, enabled_until: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { moderator.guardian }
    let(:topic_id) { topic.id }
    let(:seconds) { 3600 }
    let(:enabled_until) { nil }
    let(:ends_at) { 1.week.from_now.change(usec: 0) }

    def schedule_end(at:, owner: moderator)
      Fabricate(
        :topic_timer,
        topic:,
        user: owner,
        status_type: TopicTimer.types[:clear_slow_mode],
        execute_at: at,
      )
    end

    def slow_mode_timers
      TopicTimer.where(topic:, status_type: TopicTimer.types[:clear_slow_mode])
    end

    context "when contract is invalid" do
      let(:seconds) { -1 }

      it { is_expected.to fail_a_contract }
    end

    context "when the end time can't be read" do
      let(:enabled_until) { "garbage" }

      before { topic.update!(slow_mode_seconds: 600) }

      it "changes nothing" do
        timer = schedule_end(at: ends_at)

        expect(result).to fail_a_contract
        expect(topic.reload.slow_mode_seconds).to eq(600)
        expect(timer.reload).not_to be_trashed
      end
    end

    context "when topic is not found" do
      let(:topic_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the user can't moderate the topic" do
      fab!(:moderator) { Fabricate(:user, trust_level: TrustLevel[3]) }

      it { is_expected.to fail_a_policy(:can_update_slow_mode) }
    end

    context "when the user is trust level 4" do
      fab!(:moderator) { Fabricate(:user, trust_level: TrustLevel[4]) }

      it { is_expected.to run_successfully }
    end

    context "when turning slow mode on" do
      it { is_expected.to run_successfully }

      it "sets the interval without an end time" do
        expect { result }.to change { topic.reload.slow_mode_seconds }.to(3600)
        expect(slow_mode_timers).to be_empty
      end

      it "logs the change" do
        result

        expect(UserHistory.last).to have_attributes(
          action: UserHistory.actions[:topic_slow_mode_set],
          acting_user_id: moderator.id,
          topic_id: topic.id,
          details: "interval: 3600\nuntil: ",
        )
      end

      it "triggers topic_slow_mode_set with the user who set it" do
        events = DiscourseEvent.track_events(:topic_slow_mode_set) { result }

        expect(events.map { |event| event[:params] }).to eq(
          [[topic, nil, { acting_user: moderator }]],
        )
      end
    end

    context "with an end time" do
      let(:enabled_until) { ends_at.iso8601 }

      it "schedules the end, owned by the user who set it" do
        events = DiscourseEvent.track_events(:topic_slow_mode_set) { result }

        expect(slow_mode_timers.sole).to have_attributes(user: moderator, execute_at: ends_at)
        expect(events.sole[:params]).to eq([topic, ends_at, { acting_user: moderator }])
      end

      it "moves an end scheduled by someone else, keeping its owner" do
        timer = schedule_end(at: 1.day.from_now, owner: other_moderator)
        topic.update!(slow_mode_seconds: 3600)

        events = DiscourseEvent.track_events(:topic_slow_mode_set) { result }

        expect(slow_mode_timers.sole).to have_attributes(
          id: timer.id,
          user: other_moderator,
          execute_at: ends_at,
        )
        expect(events.sole[:params]).to eq([topic, ends_at, { acting_user: moderator }])
      end

      it "reports the user who set it as changing the end, even on someone else's timer" do
        events = DiscourseEvent.track_events(:topic_timer_changed) { result }
        expect(events.map { |event| event[:params].values_at(1, -1) }).to eq(
          [[:created, { acting_user: moderator }]],
        )

        slow_mode_timers.sole.update!(user: other_moderator)
        params[:enabled_until] = 2.weeks.from_now.iso8601
        events =
          DiscourseEvent.track_events(:topic_timer_changed) do
            described_class.call(params:, **dependencies)
          end
        expect(events.map { |event| event[:params].values_at(1, -1) }).to eq(
          [[:updated, { acting_user: moderator }]],
        )
      end

      it "keeps a single end when the topic has several" do
        kept = schedule_end(at: 1.day.from_now, owner: other_moderator)
        duplicate = schedule_end(at: 2.days.from_now)

        result

        expect(slow_mode_timers.sole).to have_attributes(id: kept.id, execute_at: ends_at)
        expect(duplicate.reload).to have_attributes(trashed?: true, deleted_by: moderator)
      end
    end

    context "when the end time is removed" do
      before { topic.update!(slow_mode_seconds: 3600) }

      it "cancels the end and triggers topic_slow_mode_set without one" do
        timer = schedule_end(at: ends_at, owner: other_moderator)

        events = DiscourseEvent.track_events(:topic_slow_mode_set) { result }

        expect(timer.reload).to have_attributes(trashed?: true, deleted_by: moderator)
        expect(events.sole[:params]).to eq([topic, nil, { acting_user: moderator }])
      end
    end

    context "when nothing changes" do
      let(:enabled_until) { ends_at.iso8601 }

      before do
        topic.update!(slow_mode_seconds: 3600)
        schedule_end(at: ends_at)
      end

      it { is_expected.to run_successfully }

      it "neither logs nor triggers an event" do
        events = DiscourseEvent.track_events(:topic_slow_mode_set) { result }

        expect(events).to be_empty
        expect(UserHistory.where(topic_id: topic.id)).to be_empty
      end
    end

    context "when turning slow mode off" do
      let(:seconds) { 0 }

      before { topic.update!(slow_mode_seconds: 3600) }

      it { is_expected.to run_successfully }

      it "clears the interval and cancels every end" do
        timers = [schedule_end(at: ends_at), schedule_end(at: ends_at, owner: other_moderator)]

        expect { result }.to change { topic.reload.slow_mode_seconds }.to(0)
        expect(timers.map(&:reload)).to all have_attributes(trashed?: true, deleted_by: moderator)
      end

      it "logs the change" do
        result

        expect(UserHistory.last).to have_attributes(
          action: UserHistory.actions[:topic_slow_mode_removed],
          acting_user_id: moderator.id,
          topic_id: topic.id,
        )
      end

      it "triggers topic_slow_mode_cleared with the user who cleared it" do
        events =
          DiscourseEvent
            .track_events { result }
            .select { |event| event[:event_name].to_s.start_with?("topic_slow_mode") }

        expect(events.map { |event| [event[:event_name], event[:params]] }).to eq(
          [[:topic_slow_mode_cleared, [topic, { acting_user: moderator }]]],
        )
      end
    end

    context "when slow mode is already off" do
      let(:seconds) { 0 }

      it "cancels a leftover end without logging or triggering an event" do
        timer = schedule_end(at: ends_at)

        events = DiscourseEvent.track_events(:topic_slow_mode_cleared) { result }

        expect(result).to run_successfully
        expect(timer.reload).to be_trashed
        expect(events).to be_empty
        expect(UserHistory.where(topic_id: topic.id)).to be_empty
      end
    end
  end
end
