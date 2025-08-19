# frozen_string_literal: true

describe RRuleConfigurator do
  let(:time) { Time.now }

  before { freeze_time Time.utc(2020, 8, 12, 16, 32) }

  describe ".rule" do
    context "with every_day recurrence" do
      it "generates the correct rule" do
        rule = RRuleConfigurator.rule(recurrence: "every_day", starts_at: time)
        expect(rule).to eq("FREQ=DAILY")
      end
    end

    context "with every_month recurrence" do
      it "generates the correct rule for the second Wednesday of the month" do
        # August 12, 2020 was the second Wednesday of the month
        rule = RRuleConfigurator.rule(recurrence: "every_month", starts_at: time)
        expect(rule).to eq("FREQ=MONTHLY;BYDAY=2WE")
      end

      it "generates the correct rule for the first Monday of the month" do
        first_monday = Time.utc(2020, 8, 3, 16, 32) # First Monday of August 2020
        rule = RRuleConfigurator.rule(recurrence: "every_month", starts_at: first_monday)
        expect(rule).to eq("FREQ=MONTHLY;BYDAY=1MO")
      end

      it "generates the correct rule for the last day of the month" do
        last_day = Time.utc(2020, 8, 31, 16, 32) # Last day of August 2020
        rule = RRuleConfigurator.rule(recurrence: "every_month", starts_at: last_day)
        expect(rule).to eq("FREQ=MONTHLY;BYDAY=5MO")
      end
    end

    context "with every_weekday recurrence" do
      it "generates the correct rule" do
        rule = RRuleConfigurator.rule(recurrence: "every_weekday", starts_at: time)
        expect(rule).to eq("FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR")
      end
    end

    context "with every_two_weeks recurrence" do
      it "generates the correct rule" do
        rule = RRuleConfigurator.rule(recurrence: "every_two_weeks", starts_at: time)
        expect(rule).to eq("FREQ=WEEKLY;INTERVAL=2;")
      end
    end

    context "with every_four_weeks recurrence" do
      it "generates the correct rule" do
        rule = RRuleConfigurator.rule(recurrence: "every_four_weeks", starts_at: time)
        expect(rule).to eq("FREQ=WEEKLY;INTERVAL=4;")
      end
    end

    context "with every_week recurrence (default)" do
      it "generates the correct rule" do
        rule = RRuleConfigurator.rule(recurrence: "every_week", starts_at: time)
        expect(rule).to eq("FREQ=WEEKLY;BYDAY=WE")
      end

      it "uses the day of the week from starts_at" do
        monday = Time.utc(2020, 8, 10, 16, 32) # A Monday
        rule = RRuleConfigurator.rule(recurrence: "every_week", starts_at: monday)
        expect(rule).to eq("FREQ=WEEKLY;BYDAY=MO")
      end
    end

    context "with an unknown recurrence" do
      it "defaults to every_week" do
        rule = RRuleConfigurator.rule(recurrence: "invalid_recurrence", starts_at: time)
        expect(rule).to eq("FREQ=WEEKLY;BYDAY=WE")
      end
    end

    context "with a recurrence_until date" do
      it "adds the UNTIL parameter to the rule" do
        recurrence_until = Time.utc(2021, 8, 12, 16, 32)
        rule = RRuleConfigurator.rule(recurrence: "every_day", starts_at: time, recurrence_until:)
        expect(rule).to eq("FREQ=DAILY;UNTIL=20210812T163200Z")
      end
    end
  end

  describe ".how_many_recurring_events" do
    context "when max_years is nil" do
      it "returns 1" do
        expect(RRuleConfigurator.how_many_recurring_events(recurrence: "every_day")).to eq(1)
      end
    end

    context "when max_years is provided" do
      it "returns the correct number for every_month" do
        expect(
          RRuleConfigurator.how_many_recurring_events(recurrence: "every_month", max_years: 2),
        ).to eq(24)
      end

      it "returns the correct number for every_four_weeks" do
        expect(
          RRuleConfigurator.how_many_recurring_events(recurrence: "every_four_weeks", max_years: 2),
        ).to eq(26)
      end

      it "returns the correct number for every_two_weeks" do
        expect(
          RRuleConfigurator.how_many_recurring_events(recurrence: "every_two_weeks", max_years: 2),
        ).to eq(52)
      end

      it "returns the correct number for every_weekday" do
        expect(
          RRuleConfigurator.how_many_recurring_events(recurrence: "every_weekday", max_years: 2),
        ).to eq(520)
      end

      it "returns the correct number for every_week" do
        expect(
          RRuleConfigurator.how_many_recurring_events(recurrence: "every_week", max_years: 2),
        ).to eq(104)
      end

      it "returns the correct number for every_day" do
        expect(
          RRuleConfigurator.how_many_recurring_events(recurrence: "every_day", max_years: 2),
        ).to eq(730)
      end
    end
  end
end
