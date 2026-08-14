# frozen_string_literal: true

RSpec.describe AccessControlListsController do
  fab!(:current_user, :user)

  class EvaluateModificationRequestTestTarget < ActiveRecord::Base
    include AclTarget

    self.table_name = "posts"

    def self.acl_target_key
      "evaluate_modification_request_test_target"
    end

    def self.loss_warning_permissions
      ["manage"]
    end
  end

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
          "display_name" => group.full_name,
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

  describe "#evaluate" do
    fab!(:group)

    before do
      sign_in(current_user)
      group.add(current_user)
      I18n.backend.store_translations(
        :en,
        access_control_list: {
          errors: {
            evaluate_modification_request_test_target_user_will_lose_permission:
              "You will lose permission if you make this change. Continue?",
            evaluate_modification_request_test_target_user_will_lose_permission_on_create:
              "You will not have permission if you create this target. Continue?",
          },
        },
      )
    end

    it "returns creation-specific wording when a new target would lose a warning permission" do
      post "/access-control/evaluate.json",
           params: {
             target_type: "EvaluateModificationRequestTestTarget",
             new_acl: [{ type: "group", id: group.id, permission: "view" }],
           },
           as: :json

      expect(response.status).to eq(422)
      expect(response.parsed_body).to eq(
        {
          "errors" => ["You will not have permission if you create this target. Continue?"],
          "extras" => {
            "current_user_will_lose_permission" => true,
            "loss_warning_permissions" => ["manage"],
          },
        },
      )
    end

    it "retains edit wording when an existing target would lose a warning permission" do
      post "/access-control/evaluate.json",
           params: {
             target_id: Fabricate(:post).id,
             target_type: "EvaluateModificationRequestTestTarget",
             new_acl: [{ type: "group", id: group.id, permission: "view" }],
           },
           as: :json

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(
        "You will lose permission if you make this change. Continue?",
      )
    end

    it "returns generic creation wording when a new target would grant no access" do
      EvaluateModificationRequestTestTarget.stubs(:loss_warning_permissions).returns([])

      post "/access-control/evaluate.json",
           params: {
             target_type: "EvaluateModificationRequestTestTarget",
             new_acl: [],
           },
           as: :json

      expect(response.status).to eq(422)
      expect(response.parsed_body).to eq(
        {
          "errors" => [
            I18n.t("access_control_list.errors.user_will_not_have_permission_on_create"),
          ],
          "extras" => {
            "current_user_will_lose_permission" => true,
          },
        },
      )
    end
  end
end
