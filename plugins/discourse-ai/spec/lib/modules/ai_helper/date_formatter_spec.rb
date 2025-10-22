# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::DateFormatter do
  fab!(:user)

  # Reference time is Tuesday Jan 16th, 2024 at 2:30 PM Sydney time
  let(:sydney_reference) { DateTime.parse("2024-01-16 14:30:00 +11:00") }

  before { enable_current_plugin }

  describe ".process_date_placeholders" do
    describe "with Sydney timezone" do
      before do
        user.user_option.update!(timezone: "Australia/Sydney")
        freeze_time(sydney_reference)
      end

      describe "date_time_offset_minutes" do
        it "handles minute offsets" do
          expect(
            described_class.process_date_placeholders(
              "Meeting in {{date_time_offset_minutes:30}}",
              user,
            ),
          ).to eq("Meeting in [date=2024-01-16 time=15:00:00 timezone=\"Australia/Sydney\"]")

          expect(
            described_class.process_date_placeholders(
              "Meeting in {{date_time_offset_minutes:90}}",
              user,
            ),
          ).to eq("Meeting in [date=2024-01-16 time=16:00:00 timezone=\"Australia/Sydney\"]")
        end

        it "handles minute ranges" do
          expect(
            described_class.process_date_placeholders(
              "Meeting {{date_time_offset_minutes:60:180}}",
              user,
            ),
          ).to eq(
            "Meeting [date-range from=2024-01-16T15:30:00 to=2024-01-16T17:30:00 timezone=\"Australia/Sydney\"]",
          )
        end
      end

      describe "date_offset_days" do
        it "handles day offsets" do
          expect(
            described_class.process_date_placeholders("Due {{date_offset_days:1}}", user),
          ).to eq("Due [date=2024-01-17 timezone=\"Australia/Sydney\"]")

          expect(
            described_class.process_date_placeholders("Due {{date_offset_days:7}}", user),
          ).to eq("Due [date=2024-01-23 timezone=\"Australia/Sydney\"]")
        end

        it "handles day ranges" do
          expect(
            described_class.process_date_placeholders("Event {{date_offset_days:1:3}}", user),
          ).to eq("Event [date-range from=2024-01-17 to=2024-01-19 timezone=\"Australia/Sydney\"]")
        end
      end

      describe "datetime" do
        it "handles absolute times today" do
          expect(
            described_class.process_date_placeholders("Meeting at {{datetime:2pm}}", user),
          ).to eq("Meeting at [date=2024-01-16 time=14:00:00 timezone=\"Australia/Sydney\"]")

          expect(
            described_class.process_date_placeholders("Meeting at {{datetime:10pm}}", user),
          ).to eq("Meeting at [date=2024-01-16 time=22:00:00 timezone=\"Australia/Sydney\"]")
        end

        it "handles absolute times with day offset" do
          expect(
            described_class.process_date_placeholders("Meeting {{datetime:2pm+1}}", user),
          ).to eq("Meeting [date=2024-01-17 time=14:00:00 timezone=\"Australia/Sydney\"]")
        end

        it "handles time ranges" do
          expect(
            described_class.process_date_placeholders("Meeting {{datetime:2pm:4pm}}", user),
          ).to eq(
            "Meeting [date-range from=2024-01-16T14:00:00 to=2024-01-16T16:00:00 timezone=\"Australia/Sydney\"]",
          )
        end

        it "handles time ranges with day offsets" do
          expect(
            described_class.process_date_placeholders("Meeting {{datetime:2pm+1:4pm+1}}", user),
          ).to eq(
            "Meeting [date-range from=2024-01-17T14:00:00 to=2024-01-17T16:00:00 timezone=\"Australia/Sydney\"]",
          )
        end

        it "handles 12-hour time edge cases" do
          expect(described_class.process_date_placeholders("At {{datetime:12am}}", user)).to eq(
            "At [date=2024-01-16 time=00:00:00 timezone=\"Australia/Sydney\"]",
          )

          expect(described_class.process_date_placeholders("At {{datetime:12pm}}", user)).to eq(
            "At [date=2024-01-16 time=12:00:00 timezone=\"Australia/Sydney\"]",
          )
        end
      end

      describe "next_week" do
        it "handles next week days" do
          expect(
            described_class.process_date_placeholders("Meeting {{next_week:tuesday}}", user),
          ).to eq("Meeting [date=2024-01-23 timezone=\"Australia/Sydney\"]")
        end

        it "handles next week with specific times" do
          expect(
            described_class.process_date_placeholders("Meeting {{next_week:tuesday-2pm}}", user),
          ).to eq("Meeting [date=2024-01-23 time=14:00:00 timezone=\"Australia/Sydney\"]")
        end

        it "handles next week time ranges" do
          expect(
            described_class.process_date_placeholders(
              "Meeting {{next_week:tuesday-1pm:tuesday-3pm}}",
              user,
            ),
          ).to eq(
            "Meeting [date-range from=2024-01-23T13:00:00 to=2024-01-23T15:00:00 timezone=\"Australia/Sydney\"]",
          )
        end
      end
    end

    describe "with Los Angeles timezone" do
      before do
        user.user_option.update!(timezone: "America/Los_Angeles")
        # Still freeze at Sydney time, but formatter should work in LA time
        freeze_time(sydney_reference)
      end

      it "handles current time conversions" do
        # When it's 2:30 PM Tuesday in Sydney
        # It's 7:30 PM Monday in LA
        expect(
          described_class.process_date_placeholders(
            "Meeting {{date_time_offset_minutes:30}}",
            user,
          ),
        ).to eq("Meeting [date=2024-01-15 time=20:00:00 timezone=\"America/Los_Angeles\"]")
      end

      it "handles absolute times" do
        expect(described_class.process_date_placeholders("Meeting {{datetime:2pm}}", user)).to eq(
          "Meeting [date=2024-01-15 time=14:00:00 timezone=\"America/Los_Angeles\"]",
        )
      end

      describe "next_week" do
        it "handles next week days in LA time" do
          # From Monday night in LA (Tuesday in Sydney)
          expect(
            described_class.process_date_placeholders("Meeting {{next_week:tuesday}}", user),
          ).to eq("Meeting [date=2024-01-23 timezone=\"America/Los_Angeles\"]")
        end

        it "handles next week with specific times in LA" do
          expect(
            described_class.process_date_placeholders("Meeting {{next_week:tuesday-2pm}}", user),
          ).to eq("Meeting [date=2024-01-23 time=14:00:00 timezone=\"America/Los_Angeles\"]")
        end

        it "handles next week time ranges in LA" do
          expect(
            described_class.process_date_placeholders(
              "Meeting {{next_week:tuesday-1pm:tuesday-3pm}}",
              user,
            ),
          ).to eq(
            "Meeting [date-range from=2024-01-23T13:00:00 to=2024-01-23T15:00:00 timezone=\"America/Los_Angeles\"]",
          )
        end
      end

      it "handles day transitions across timezones" do
        expect(described_class.process_date_placeholders("Due {{date_offset_days:1}}", user)).to eq(
          "Due [date=2024-01-16 timezone=\"America/Los_Angeles\"]",
        )
      end
    end

    describe "with UTC timezone" do
      before do
        user.user_option.update!(timezone: nil) # defaults to UTC
        freeze_time(sydney_reference)
      end

      it "defaults to UTC for users without timezone" do
        # When it's 2:30 PM in Sydney
        # It's 3:30 AM in UTC
        expect(
          described_class.process_date_placeholders(
            "Meeting {{date_time_offset_minutes:30}}",
            user,
          ),
        ).to eq("Meeting [date=2024-01-16 time=04:00:00 timezone=\"UTC\"]")
      end

      describe "next_week" do
        it "handles next week calculations in UTC" do
          expect(
            described_class.process_date_placeholders("Meeting {{next_week:tuesday-2pm}}", user),
          ).to eq("Meeting [date=2024-01-23 time=14:00:00 timezone=\"UTC\"]")
        end
      end
    end

    describe "error handling" do
      before do
        user.user_option.update!(timezone: "Australia/Sydney")
        freeze_time(sydney_reference)
      end

      it "raises on invalid day name" do
        expect {
          described_class.process_date_placeholders("Meeting {{next_week:notaday}}", user)
        }.to raise_error(ArgumentError)
      end

      it "raises on invalid time format" do
        expect {
          described_class.process_date_placeholders("Meeting {{datetime:25pm}}", user)
        }.to raise_error(ArgumentError)
      end
    end

    describe "mixed formats" do
      before do
        user.user_option.update!(timezone: "Australia/Sydney")
        freeze_time(sydney_reference)
      end

      it "handles multiple different formats in the same text" do
        input = [
          "Meeting {{datetime:2pm+1}},",
          "duration {{date_time_offset_minutes:60:180}},",
          "repeats until {{date_offset_days:7}}",
          "with sessions {{next_week:tuesday-1pm:tuesday-3pm}}",
        ].join(" ")

        expected = [
          "Meeting [date=2024-01-17 time=14:00:00 timezone=\"Australia/Sydney\"],",
          "duration [date-range from=2024-01-16T15:30:00 to=2024-01-16T17:30:00 timezone=\"Australia/Sydney\"],",
          "repeats until [date=2024-01-23 timezone=\"Australia/Sydney\"]",
          "with sessions [date-range from=2024-01-23T13:00:00 to=2024-01-23T15:00:00 timezone=\"Australia/Sydney\"]",
        ].join(" ")

        expect(described_class.process_date_placeholders(input, user)).to eq(expected)
      end
    end
  end
end
