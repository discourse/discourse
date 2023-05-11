# frozen_string_literal: true

RSpec.describe Admin::VersionsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user) }

  before do
    Jobs::VersionCheck.any_instance.stubs(:execute).returns(true)
    DiscourseUpdates.stubs(:updated_at).returns(2.hours.ago)
    DiscourseUpdates.stubs(:latest_version).returns("1.2.33")
    DiscourseUpdates.stubs(:critical_updates_available?).returns(false)
  end

  describe "#show" do
    shared_examples "version info accessible" do
      it "should return the currently available version" do
        get "/admin/version_check.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["latest_version"]).to eq("1.2.33")
      end

      it "should return the installed version" do
        get "/admin/version_check.json"
        json = response.parsed_body
        expect(response.status).to eq(200)
        expect(json["installed_version"]).to eq(Discourse::VERSION::STRING)
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      include_examples "version info accessible"
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "version info accessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/version_check.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(response.parsed_body["latest_version"]).to be_nil
        expect(response.parsed_body["installed_version"]).to be_nil
      end
    end
  end
end
