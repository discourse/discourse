# frozen_string_literal: true

require "rails_helper"

module DiscourseCalendar
  describe Holiday do
    describe ".find_holidays_for" do
      before { DisabledHoliday.create!(holiday_name: "Saudi National Day", region_code: "sa") }

      let(:holidays) do
        Holiday.find_holidays_for(
          region_code: "sa",
          start_date: "2023-02-21",
          end_date: "2023-09-23",
        )
      end

      it "returns a list of holidays indicating whether a holiday is disabled or not" do
        expect(holidays).to include(
          a_hash_including({ name: "Saudi National Day", regions: [:sa], disabled: true }),
        )

        expect(holidays).to include(
          a_hash_including({ name: "Foundation Day", regions: [:sa], disabled: false }),
        )
      end

      describe "dates holidays are observed on" do
        let(:holidays) do
          Holiday.find_holidays_for(
            region_code: "sg",
            start_date: "2021-12-31",
            end_date: "2022-05-31",
            show_holiday_observed_on_dates: show_holiday_observed_on_dates,
          )
        end

        context "when `show_holiday_observed_on_dates` is set to true" do
          let(:show_holiday_observed_on_dates) { true }

          it "returns the holidays with the date the holidays are observed on" do
            expect(holidays).to include(
              a_hash_including(
                { name: "New Year's Day", date: Date.new(2021, 12, 31), regions: [:sg] },
              ),
            )

            expect(holidays).to include(
              a_hash_including({ name: "Labour Day", date: Date.new(2022, 5, 2), regions: [:sg] }),
            )
          end
        end

        context "when `show_holiday_observed_on_dates` is set to false" do
          let(:show_holiday_observed_on_dates) { false }

          it "returns the holidays with the actual holiday dates" do
            expect(holidays).to include(
              a_hash_including(
                { name: "New Year's Day", date: Date.new(2022, 1, 1), regions: [:sg] },
              ),
            )

            expect(holidays).to include(
              a_hash_including({ name: "Labour Day", date: Date.new(2022, 5, 1), regions: [:sg] }),
            )
          end
        end
      end
    end
  end
end
