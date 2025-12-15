# frozen_string_literal: true

RSpec.describe DiscourseRewind::RewindsController do
  before { SiteSetting.discourse_rewind_enabled = true }

  describe "#dismiss" do
    it "requires login" do
      post "/rewinds/dismiss.json"
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      fab!(:user)
      before { sign_in(user) }

      it "sets dismissed_at on user_option" do
        freeze_time DateTime.parse("2022-12-24 10:00:00")

        post "/rewinds/dismiss.json"

        expect(response.status).to eq(204)
        expect(user.user_option.reload.discourse_rewind_dismissed_at).to eq_time(Time.current)
      end

      it "returns dismissed state via session/current endpoint" do
        freeze_time DateTime.parse("2022-12-24")
        user.user_option.update!(discourse_rewind_dismissed_at: Time.current)

        get "/session/current.json"

        expect(
          response.parsed_body.dig("current_user", "user_option", "discourse_rewind_dismissed"),
        ).to eq(true)
      end
    end
  end

  describe "#index" do
    fab!(:user)

    before { sign_in(user) }

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
    fab!(:user)

    before { sign_in(user) }

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

  describe "#toggle_share" do
    it "requires login" do
      put "/rewinds/toggle-share.json"
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      fab!(:user)
      before { sign_in(user) }

      it "toggles share preference from false to true" do
        user.user_option.update!(discourse_rewind_share_publicly: false)

        put "/rewinds/toggle-share.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["shared"]).to eq(true)
        expect(user.user_option.reload.discourse_rewind_share_publicly).to eq(true)
      end

      it "toggles share preference from true to false" do
        user.user_option.update!(discourse_rewind_share_publicly: true)

        put "/rewinds/toggle-share.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["shared"]).to eq(false)
        expect(user.user_option.reload.discourse_rewind_share_publicly).to eq(false)
      end

      context "when user has hidden profile" do
        before { user.user_option.update!(hide_profile: true) }

        it "prevents enabling share when profile is hidden" do
          user.user_option.update!(discourse_rewind_share_publicly: false)

          put "/rewinds/toggle-share.json"

          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"].first).to eq(
            I18n.t("discourse_rewind.cannot_share_when_profile_hidden"),
          )
          expect(user.user_option.reload.discourse_rewind_share_publicly).to eq(false)
        end

        it "allows disabling share even when profile is hidden" do
          user.user_option.update!(discourse_rewind_share_publicly: true)

          put "/rewinds/toggle-share.json"

          expect(response.status).to eq(200)
          expect(response.parsed_body["shared"]).to eq(false)
          expect(user.user_option.reload.discourse_rewind_share_publicly).to eq(false)
        end
      end
    end
  end
end
