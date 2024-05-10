# frozen_string_literal: true

describe "Recurring" do
  fab!(:user)
  fab!(:topic)
  fab!(:automation) do
    Fabricate(
      :automation,
      trigger: DiscourseAutomation::Triggers::RECURRING,
      script: "nothing_about_us",
    )
  end

  def upsert_period_field!(interval, frequency)
    metadata = { value: { interval: interval, frequency: frequency } }
    automation.upsert_field!("recurrence", "period", metadata, target: "trigger")
  end

  it "allows manual trigger" do
    triggerable = DiscourseAutomation::Triggerable.new(automation.trigger)
    expect(triggerable.settings[DiscourseAutomation::Triggerable::MANUAL_TRIGGER_KEY]).to eq(true)
  end

  describe "updating trigger" do
    context "when date is in future" do
      before { freeze_time Time.parse("2021-06-04 10:00 UTC") }

      it "creates a pending trigger with execute_at set to the start_date" do
        expect {
          automation.upsert_field!(
            "start_date",
            "date_time",
            { value: 2.hours.from_now },
            target: "trigger",
          )
          upsert_period_field!(1, "hour")
        }.to change { automation.pending_automations.count }.by(1)

        expect(automation.pending_automations.last.execute_at).to be_within_one_second_of(
          2.hours.from_now,
        )
      end
    end

    context "when date is in past" do
      it "doesn’t create a pending trigger" do
        expect {
          automation.upsert_field!(
            "start_date",
            "date_time",
            { value: 2.hours.ago },
            target: "trigger",
          )
        }.not_to change { automation.pending_automations.count }
      end
    end
  end

  context "when updating automation" do
    fab!(:automation) do
      Fabricate(:automation, trigger: DiscourseAutomation::Triggers::RECURRING, script: "test")
    end

    before do
      DiscourseAutomation::Scriptable.add("test") do
        triggerables [DiscourseAutomation::Triggers::RECURRING]
        field :test, component: :text
      end

      automation.upsert_field!(
        "start_date",
        "date_time",
        { value: 2.hours.from_now },
        target: "trigger",
      )
      upsert_period_field!(1, "week")

      automation.upsert_field!("test", "text", { value: "something" }, target: "script")
    end

    context "when interval changes" do
      before { freeze_time(DateTime.parse("2024-05-23")) }

      context "when start_date is in the future" do
        before do
          automation.upsert_field!(
            "start_date",
            "date_time",
            { value: 5.days.from_now },
            target: "trigger",
          )
        end

        it "recreates pending automation with execute_at set to start_date" do
          upsert_period_field!(4, "week")

          expect(automation.pending_automations.count).to eq(1)
          expect(automation.pending_automations.last.execute_at).to be_within_one_second_of(
            5.days.from_now,
          )
        end
      end

      context "when start_date is in the past" do
        before do
          automation.upsert_field!(
            "start_date",
            "date_time",
            { value: 4.days.ago },
            target: "trigger",
          )
        end

        it "recreates pending automation with execute_at set to the first occurrence date after the current time" do
          upsert_period_field!(3, "day")

          expect(automation.pending_automations.count).to eq(1)
          expect(automation.pending_automations.last.execute_at).to be_within_one_second_of(
            Time.zone.now + 2.days,
          )
        end
      end
    end

    context "when frequency changes" do
      before { freeze_time(DateTime.parse("2024-05-23")) }

      context "when start_date is in the future" do
        before do
          automation.upsert_field!(
            "start_date",
            "date_time",
            { value: 2.hours.from_now },
            target: "trigger",
          )
        end

        it "recreates pending automation with execute_at set to start_date" do
          upsert_period_field!(1, "hour")

          expect(automation.pending_automations.count).to eq(1)
          expect(automation.pending_automations.last.execute_at).to be_within_one_second_of(
            2.hours.from_now,
          )
        end
      end

      context "when start_date is in the past" do
        before do
          automation.upsert_field!(
            "start_date",
            "date_time",
            { value: 3.days.ago },
            target: "trigger",
          )
        end

        it "recreates pending automation with execute_at set to the first occurrence date after the current time" do
          upsert_period_field!(2, "hour")

          expect(automation.pending_automations.count).to eq(1)
          expect(automation.pending_automations.last.execute_at).to be_within_one_second_of(
            Time.zone.now + 2.hour,
          )
        end
      end
    end

    context "when a non recurrence related field changes" do
      it "doesn't reset the pending automations" do
        expect {
          automation.upsert_field!("test", "text", { value: "somethingelse" }, target: "script")
        }.to_not change { automation.pending_automations.last.execute_at }
        expect(automation.pending_automations.count).to eq(1)
      end

      context "when there are no existing pending automations" do
        before { automation.pending_automations.destroy_all }

        it "creates a new one" do
          expect {
            automation.upsert_field!("test", "text", { value: "somethingelse" }, target: "script")
          }.to change { automation.pending_automations.count }.by(1)
        end
      end
    end
  end

  context "when trigger is called" do
    before do
      freeze_time Time.zone.parse("2021-06-04 10:00")
      automation.fields.insert!(
        {
          name: "start_date",
          component: "date_time",
          metadata: {
            value: 2.hours.ago,
          },
          target: "trigger",
          created_at: Time.now,
          updated_at: Time.now,
        },
      )
      metadata = { value: { interval: "1", frequency: "week" } }
      automation.fields.insert!(
        {
          name: "recurrence",
          component: "period",
          metadata: metadata,
          target: "trigger",
          created_at: Time.now,
          updated_at: Time.now,
        },
      )
    end

    it "creates the next iteration" do
      expect { automation.trigger! }.to change { automation.pending_automations.count }.by(1)

      pending_automation = automation.pending_automations.last

      start_date = Time.parse(automation.trigger_field("start_date")["value"])
      expect(pending_automation.execute_at).to be_within_one_minute_of(start_date + 7.days)
    end

    describe "every_month" do
      before { upsert_period_field!(1, "month") }

      it "creates the next iteration one month later" do
        automation.trigger!

        pending_automation = automation.pending_automations.last
        expect(pending_automation.execute_at).to be_within_one_minute_of(
          Time.parse("2021-07-02 08:00:00 UTC"),
        )
      end
    end

    describe "every_day" do
      before do
        automation.upsert_field!(
          "start_date",
          "date_time",
          { value: 1.minute.from_now },
          target: "trigger",
        )
        upsert_period_field!(1, "day")
      end

      it "creates the next iteration one day later" do
        automation.trigger!

        pending_automation = automation.pending_automations.last
        start_date = Time.parse(automation.trigger_field("start_date")["value"])
        expect(pending_automation.execute_at).to be_within_one_minute_of(start_date)
      end
    end

    describe "every_weekday" do
      it "creates the next iteration one day after without Saturday/Sunday" do
        upsert_period_field!(1, "weekday")
        automation.trigger!

        pending_automation = automation.pending_automations.last
        start_date = Time.parse(automation.trigger_field("start_date")["value"])
        expect(pending_automation.execute_at).to be_within_one_minute_of(start_date + 3.day)
      end

      it "creates the next iteration three days after without Saturday/Sunday" do
        now = DateTime.parse("2022-05-19").end_of_day
        start_date = now - 1.hour
        freeze_time now

        automation.pending_automations.destroy_all
        automation.upsert_field!(
          "start_date",
          "date_time",
          { value: start_date },
          target: "trigger",
        )
        upsert_period_field!(3, "weekday")

        automation.trigger!

        pending_automation = automation.pending_automations.last
        expect(pending_automation.execute_at).to be_within_one_minute_of(start_date + 5.days)
      end
    end

    describe "every_hour" do
      before { upsert_period_field!(1, "hour") }

      it "creates the next iteration one hour later" do
        automation.trigger!

        pending_automation = automation.pending_automations.last
        expect(pending_automation.execute_at).to be_within_one_minute_of(
          (Time.zone.now + 1.hour).beginning_of_hour,
        )
      end
    end

    describe "every_minute" do
      before { upsert_period_field!(1, "minute") }

      it "creates the next iteration one minute later" do
        automation.trigger!

        pending_automation = automation.pending_automations.last
        expect(pending_automation.execute_at).to be_within_one_minute_of(
          (Time.zone.now + 1.minute).beginning_of_minute,
        )
      end
    end

    describe "every_year" do
      before { upsert_period_field!(1, "year") }

      it "creates the next iteration one year later" do
        automation.trigger!

        pending_automation = automation.pending_automations.last
        start_date = Time.parse(automation.trigger_field("start_date")["value"])
        expect(pending_automation.execute_at).to be_within_one_minute_of(start_date + 1.year)
      end
    end

    describe "every_other_week" do
      before { upsert_period_field!(2, "week") }

      it "creates the next iteration two weeks later" do
        automation.trigger!

        pending_automation = automation.pending_automations.last
        start_date = Time.parse(automation.trigger_field("start_date")["value"])
        expect(pending_automation.execute_at).to be_within_one_minute_of(start_date + 2.weeks)
      end
    end
  end
end
