# frozen_string_literal: true

RSpec.describe Admin::SearchLogsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  before { SearchLog.log(term: "ruby", search_type: :header, ip_address: "127.0.0.1") }

  after { SearchLog.clear_debounce_cache! }

  describe "#index" do
    shared_examples "search logs accessible" do
      it "returns search logs" do
        get "/admin/logs/search_logs.json"

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json[0]["term"]).to eq("ruby")
        expect(json[0]["searches"]).to eq(1)
        expect(json[0]["ctr"]).to eq(0)
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "search logs accessible"

      it "counts both anonymous and logged-in members' searches by default" do
        Fabricate(:search_log, term: "discobot", user: user)
        Fabricate.times(2, :search_log, term: "discobot")

        get "/admin/logs/search_logs.json"

        row = response.parsed_body.find { |entry| entry["term"] == "discobot" }
        expect(row["searches"]).to eq(3)
      end

      it "returns only non-staff users' searches with the non_staff_only search type" do
        Fabricate(:search_log, term: "member-search", user: user)
        Fabricate(:search_log, term: "admin-search", user: admin)
        Fabricate(:search_log, term: "moderator-search", user: moderator)
        Fabricate(:search_log, term: "anonymous-search", user: nil)

        get "/admin/logs/search_logs.json", params: { search_type: "non_staff_only" }

        expect(response.parsed_body.map { |entry| [entry["term"], entry["searches"]] }).to eq(
          [["member-search", 1]],
        )
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "search logs accessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/logs/search_logs.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#term" do
    shared_examples "search log term accessible" do
      it "returns search log term" do
        get "/admin/logs/search_logs/term.json", params: { term: "ruby" }

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["term"]["type"]).to eq("search_log_term")
        expect(json["term"]["search_result"]).to be_present
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "search log term accessible"

      it "returns only non-staff users' searches with the non_staff_only search type" do
        Fabricate(:search_log, term: "discobot", user: user)
        Fabricate(:search_log, term: "discobot", user: admin)
        Fabricate(:search_log, term: "discobot", user: moderator)
        Fabricate(:search_log, term: "discobot", user: nil)

        get "/admin/logs/search_logs/term.json",
            params: {
              term: "discobot",
              search_type: "non_staff_only",
            }
        expect(response.parsed_body["term"]["data"].sum { |point| point["y"] }).to eq(1)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "search log term accessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/logs/search_logs/term.json", params: { term: "ruby" }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end
end
