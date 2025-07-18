# frozen_string_literal: true

require "rails_helper"

module Admin::DiscourseCalendar
  describe AdminHolidaysController do
    fab!(:admin) { Fabricate(:user, admin: true) }
    fab!(:member) { Fabricate(:user) }

    before { SiteSetting.calendar_enabled = calendar_enabled }

    describe "#index" do
      context "when the calendar plugin is enabled" do
        let(:calendar_enabled) { true }

        context "when an admin is signed in" do
          before { sign_in(admin) }

          it "returns a list of holidays for a given region" do
            freeze_time DateTime.parse("2022-12-24 12:00")

            get "/admin/discourse-calendar/holiday-regions/mx/holidays.json"

            expect(response.parsed_body["holidays"]).to include(
              {
                "date" => "2022-01-01",
                "name" => "Año nuevo",
                "regions" => ["mx"],
                "disabled" => false,
              },
              {
                "date" => "2022-09-16",
                "name" => "Día de la Independencia",
                "regions" => ["mx"],
                "disabled" => false,
              },
            )
          end

          it "returns a 422 and an error message for an invalid region" do
            get "/admin/discourse-calendar/holiday-regions/regionxyz/holidays.json"

            expect(response.status).to eq(422)
            expect(response.parsed_body["errors"]).to include(
              I18n.t("system_messages.discourse_calendar_holiday_region_invalid"),
            )
          end
        end

        it "returns a 404 for a member" do
          sign_in(member)
          get "/admin/discourse-calendar/holiday-regions/mx/holidays.json"

          expect(response.status).to eq(404)
        end
      end

      context "when the calendar plugin is not enabled" do
        let(:calendar_enabled) { false }

        it "returns a 404 for an admin" do
          sign_in(admin)
          get "/admin/discourse-calendar/holiday-regions/mx/holidays.json"

          expect(response.status).to eq(404)
        end

        it "returns a 404 for a member" do
          sign_in(member)
          get "/admin/discourse-calendar/holiday-regions/mx/holidays.json"

          expect(response.status).to eq(404)
        end
      end
    end

    describe "#disable" do
      context "when the calendar plugin is enabled" do
        let(:calendar_enabled) { true }
        let(:dia_de_la_independencia) do
          { holiday_name: "Día de la Independencia", region_code: "mx" }
        end

        context "when an admin is signed in" do
          before { sign_in(admin) }

          it "disables the holiday in the specified region and returns a 200 status code" do
            post "/admin/discourse-calendar/holidays/disable.json",
                 params: {
                   disabled_holiday: dia_de_la_independencia,
                 }

            disabled_holiday = DiscourseCalendar::DisabledHoliday.last

            expect(disabled_holiday.holiday_name).to eq(dia_de_la_independencia[:holiday_name])
            expect(disabled_holiday.region_code).to eq(dia_de_la_independencia[:region_code])
            expect(disabled_holiday.disabled).to eq(true)
            expect(response.status).to eq(200)
          end

          it "returns a 400 (bad request) status code when the parameters are not valid" do
            post "/admin/discourse-calendar/holidays/disable.json", params: { disabled_holiday: {} }

            expect(response.status).to eq(400)
          end

          context "when a holiday has been added to the calendar" do
            let(:calendar_post) { create_post(raw: "[calendar]\n[/calendar]") }
            let(:australia_new_years_day) do
              { holiday_name: "New Year's Day", date: "2022-01-01", region_code: "au" }
            end
            let(:australia_day) do
              { holiday_name: "Australia Day", date: "2022-01-26", region_code: "au" }
            end

            before do
              CalendarEvent.create!(
                topic_id: calendar_post.topic_id,
                description: australia_new_years_day[:holiday_name],
                start_date: australia_new_years_day[:date],
                region: australia_new_years_day[:region_code],
              )

              CalendarEvent.create!(
                topic_id: calendar_post.topic_id,
                description: australia_day[:holiday_name],
                start_date: australia_day[:date],
                region: australia_day[:region_code],
              )
            end

            it "removes disabled holidays from the calendar" do
              post "/admin/discourse-calendar/holidays/disable.json",
                   params: {
                     disabled_holiday: {
                       holiday_name: australia_new_years_day[:holiday_name],
                       region_code: australia_new_years_day[:region_code],
                     },
                   }

              expect(
                CalendarEvent.where(
                  description: australia_new_years_day[:holiday_name],
                  region: australia_new_years_day[:region_code],
                ).count,
              ).to eq(0)

              expect(
                CalendarEvent.where(
                  description: australia_day[:holiday_name],
                  region: australia_day[:region_code],
                ).count,
              ).to eq(1)
            end
          end
        end
      end
    end

    describe "#enable" do
      context "when the calendar plugin is enabled" do
        let(:calendar_enabled) { true }

        context "when an admin is signed in" do
          before { sign_in(admin) }

          context "when there is a disabled holiday" do
            let(:hong_kong_labour_day) { { holiday_name: "Labour Day", region_code: "hk" } }

            before { DiscourseCalendar::DisabledHoliday.create!(hong_kong_labour_day) }

            it "enables a holiday (by deleting its 'disabled' record) and returns a 200 status code" do
              expect(DiscourseCalendar::DisabledHoliday.count).to eq(1)

              delete "/admin/discourse-calendar/holidays/enable.json",
                     params: {
                       disabled_holiday: hong_kong_labour_day,
                     }

              expect(DiscourseCalendar::DisabledHoliday.count).to eq(0)
              expect(response.status).to eq(200)
            end
          end

          it "returns a 422 (unprocessable entity) status code when a holiday can't be enabled" do
            delete "/admin/discourse-calendar/holidays/enable.json",
                   params: {
                     disabled_holiday: {
                       holiday_name: "Not disabled holiday",
                       region_code: "NA",
                     },
                   }

            expect(response.status).to eq(422)
          end
        end
      end
    end
  end
end
