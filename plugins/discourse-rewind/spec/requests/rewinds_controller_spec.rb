# frozen_string_literal: true

RSpec.describe DiscourseRewind::RewindsController do
  before { SiteSetting.discourse_rewind_enabled = true }

  describe "#show" do
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

      it "returns 200" do
        get "/rewinds.json"

        expect(response.status).to eq(200)
      end

      context "when reports are not found or error" do
        before do
          DiscourseRewind::Action::TopWords.stubs(:call).raises(StandardError.new("Some error"))
        end

        it "returns 404 with message" do
          get "/rewinds.json"

          expect(response.status).to eq(404)
          expect(response.parsed_body["errors"].first).to eq(
            I18n.t("discourse_rewind.report_failed"),
          )
        end
      end
    end
  end
end
