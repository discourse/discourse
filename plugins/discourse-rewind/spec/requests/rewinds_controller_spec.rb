# frozen_string_literal: true

RSpec.describe DiscourseRewind::RewindsController do
  before { SiteSetting.discourse_rewind_enabled = true }

  describe "#index" do
    fab!(:current_user, :user)

    before { sign_in(current_user) }

    context "when out of valid month" do
      before { freeze_time DateTime.parse("2022-11-24") }

      it "returns 404" do
        get "/rewinds.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("discourse_rewind.invalid_year"))
      end
    end

    context "when in valid month" do
      before { freeze_time DateTime.parse("2022-12-24") }

      it "returns 200 with reports and total_available" do
        get "/rewinds.json"

        expect(response.status).to eq(200)
        body = response.parsed_body
        expect(body).to have_key("reports")
        expect(body).to have_key("total_available")
        expect(body["reports"].size).to be <= DiscourseRewind::FetchReports::INITIAL_REPORT_COUNT
        expect(body["total_available"]).to be >= body["reports"].size
      end

      context "when some reports fail" do
        before do
          DiscourseRewind::Action::TopWords.stubs(:call).raises(StandardError.new("Some error"))
        end

        it "returns reports excluding the failed ones" do
          get "/rewinds.json"

          expect(response.status).to eq(200)
          body = response.parsed_body
          expect(body["reports"]).to be_an(Array)
          expect(body["reports"].map { |r| r["identifier"] }).not_to include("top-words")
        end
      end
    end
  end

  describe "#show" do
    fab!(:current_user, :user)

    before { sign_in(current_user) }

    context "when out of valid month" do
      before { freeze_time DateTime.parse("2022-11-24") }

      it "returns 404" do
        get "/rewinds/0.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("discourse_rewind.invalid_year"))
      end
    end

    context "when in valid month" do
      before { freeze_time DateTime.parse("2022-12-24") }

      context "when reports are not cached" do
        it "returns 404 with message" do
          get "/rewinds/0.json"

          expect(response.status).to eq(404)
          expect(response.parsed_body["errors"].first).to eq(
            I18n.t("discourse_rewind.reports_not_cached"),
          )
        end
      end

      context "when reports are cached" do
        before { get "/rewinds.json" }

        it "returns 200 with the requested report" do
          get "/rewinds/0.json"

          expect(response.status).to eq(200)
          body = response.parsed_body
          expect(body).to have_key("report")
          expect(body["report"]).to have_key("identifier")
        end

        it "returns 404 for invalid index" do
          get "/rewinds/999.json"

          expect(response.status).to eq(404)
          expect(response.parsed_body["errors"].first).to eq(
            I18n.t("discourse_rewind.report_not_found"),
          )
        end
      end
    end
  end
end
