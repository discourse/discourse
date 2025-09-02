# frozen_string_literal: true

describe RRuleGenerator do
  let(:time) { Time.now }

  before { freeze_time Time.utc(2020, 8, 12, 16, 32) }

  describe "every week" do
    context "when a rule and time are given" do
      let(:time) { Time.utc(2020, 8, 10, 16, 32) }

      it "generates the rule" do
        rrule = RRuleGenerator.generate(starts_at: time, recurrence: "every_week").first
        expect(rrule.to_s).to eq("2020-08-17 16:32:00 UTC")
      end
    end
  end

  context "when timezone given" do
    it "correctly computes the next date using the timezone" do
      timezone = "Europe/Paris"
      time = Time.utc(2020, 1, 25, 15, 36)

      freeze_time DateTime.parse("2020-02-25 15:36")

      rrule = RRuleGenerator.generate(starts_at: time, timezone:, recurrence: "every_week").first
      expect(rrule.to_s).to eq("2020-02-29 16:36:00 +0100")

      freeze_time DateTime.parse("2020-09-25 15:36")

      rrule = RRuleGenerator.generate(starts_at: time, timezone:).first
      expect(rrule.to_s).to eq("2020-09-26 16:36:00 +0200")
    end
  end

  describe "show_local_time" do
    it "generates floating time RRule without timezone when show_local_time is enabled" do
      timezone = "Europe/Prague"
      time = Time.utc(2020, 1, 25, 15, 36)

      rrule_string =
        RRuleGenerator.generate_string(
          starts_at: time,
          timezone: timezone,
          recurrence: "every_week",
          dtstart: time,
          show_local_time: true,
        )

      expect(rrule_string).to eq(
        "DTSTART:20200125T153600\nRRULE:FREQ=WEEKLY;BYDAY=SA;INTERVAL=1;WKST=MO",
      )
    end

    it "generates timezone-specific RRule when show_local_time is disabled" do
      timezone = "Europe/Prague"
      time = Time.utc(2020, 1, 25, 15, 36)

      rrule_string =
        RRuleGenerator.generate_string(
          starts_at: time,
          timezone: timezone,
          recurrence: "every_week",
          dtstart: time,
          show_local_time: false,
        )

      expect(rrule_string).to eq(
        "DTSTART:20200125T153600Z\nRRULE:FREQ=WEEKLY;BYDAY=SA;INTERVAL=1;WKST=MO",
      )
    end
  end

  describe "every day" do
    context "when a rule and time are given" do
      it "generates the rule" do
        rrule = RRuleGenerator.generate(starts_at: time, recurrence: "every_day", max_years: 1)[1]
        expect(rrule.to_s).to eq("2020-08-13 16:32:00 UTC")
      end

      context "when the given time is a valid next" do
        let(:time) { Time.utc(2020, 8, 10, 16, 32) }

        it "returns the next valid after given time and in the future" do
          rrule = RRuleGenerator.generate(starts_at: time, recurrence: "every_day").first
          expect(rrule.to_s).to eq("2020-08-12 16:32:00 UTC")
        end
      end
    end
  end
end
