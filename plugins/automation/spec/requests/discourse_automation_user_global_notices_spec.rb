# frozen_string_literal: true

require_relative "../discourse_automation_helper"

describe DiscourseAutomation::UserGlobalNoticesController do
  fab!(:user_1) { Fabricate(:user) }

  before { SiteSetting.discourse_automation_enabled = true }

  describe "#destroy" do
    let!(:notice_1) do
      DiscourseAutomation::UserGlobalNotice.create!(
        user_id: user_1.id,
        notice: "foo",
        identifier: "bar",
      )
    end

    context "when user is not logged in" do
      it "raises a 403" do
        delete "/user-global-notices/#{notice_1.id}.json"

        expect(response.status).to eq(403)
      end
    end

    context "when user is owner of the notice" do
      before { sign_in(user_1) }

      it "destroys the notice" do
        delete "/user-global-notices/#{notice_1.id}.json"

        expect(DiscourseAutomation::UserGlobalNotice.count).to eq(0)
      end
    end

    context "when user is not owner of the notice" do
      before { sign_in(Fabricate(:user)) }

      it "raises a 404" do
        delete "/user-global-notices/#{notice_1.id}.json"

        expect(response.status).to eq(404)
      end
    end
  end
end
