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

      it "returns a page of reports and the total available" do
        get "/rewinds.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.keys).to contain_exactly("reports", "total_available")
      end

      it "returns 400 for an offset past the last report" do
        get "/rewinds.json", params: { offset: DiscourseRewind::FetchReports::REPORTS.size }

        expect(response.status).to eq(400)
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
      end
    end
  end
end
