# frozen_string_literal: true

RSpec.describe AccessControlListsController do
  fab!(:current_user, :user)

  describe "#search_grantees" do
    before { sign_in(current_user) }

    it "returns matching users and groups", :aggregate_failures do
      user = Fabricate(:user, username: "acl_search_user")
      group = Fabricate(:group, name: "acl_search_group", full_name: "ACL search group")

      get "/access-control/grantees/search.json", params: { term: "acl_search" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].map { |result| result["id"] }).to contain_exactly(
        user.id,
      )
      expect(response.parsed_body["groups"]).to contain_exactly(
        {
          "id" => group.id,
          "name" => group.name,
          "full_name" => group.full_name,
          "automatic" => false,
        },
      )
    end

    it "returns no results for a blank term", :aggregate_failures do
      get "/access-control/grantees/search.json", params: { term: "" }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq({ "users" => [], "groups" => [] })
    end

    include_examples "invalid limit params",
                     "/access-control/grantees/search.json",
                     described_class::SEARCH_GRANTEES_LIMIT,
                     params: {
                       term: "acl_search",
                     }
  end

  context "when logged out" do
    it "requires login" do
      get "/access-control/grantees/search.json", params: { term: "acl_search" }

      expect(response.status).to eq(403)
    end
  end
end
