# frozen_string_literal: true

RSpec.describe Styleguide::StyleguideController do
  before { SiteSetting.styleguide_enabled = true }

  describe "#index" do
    context "when styleguide_allowed_groups includes anonymous and logged in users" do
      before do
        SiteSetting.styleguide_allowed_groups =
          "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
      end

      it "allows access for anonymous users" do
        get "/styleguide"
        expect(response.status).to eq(200)
      end

      it "allows access for logged in users" do
        sign_in(Fabricate(:user))
        get "/styleguide"
        expect(response.status).to eq(200)
      end
    end

    context "when styleguide_allowed_groups is set to staff" do
      before { SiteSetting.styleguide_allowed_groups = Group::AUTO_GROUPS[:staff] }

      it "returns 403 for anonymous users" do
        get "/styleguide"
        expect(response.status).to eq(404)
      end

      it "returns 403 for regular users" do
        sign_in(Fabricate(:user))
        get "/styleguide"
        expect(response.status).to eq(404)
      end

      it "allows access for moderators" do
        sign_in(Fabricate(:moderator))
        get "/styleguide"
        expect(response.status).to eq(200)
      end

      it "allows access for admins" do
        sign_in(Fabricate(:admin))
        get "/styleguide"
        expect(response.status).to eq(200)
      end
    end

    context "when styleguide_allowed_groups is set to a custom group" do
      fab!(:custom_group, :group)
      fab!(:group_member, :user)
      fab!(:non_member, :user)

      before do
        custom_group.add(group_member)
        SiteSetting.styleguide_allowed_groups = custom_group.id
      end

      it "returns 403 for anonymous users" do
        get "/styleguide"
        expect(response.status).to eq(404)
      end

      it "returns 403 for users not in the group" do
        sign_in(non_member)
        get "/styleguide"
        expect(response.status).to eq(404)
      end

      it "allows access for users in the group" do
        sign_in(group_member)
        get "/styleguide"
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#design_variables" do
    it "lists core's design variables and which ones theme styles may change" do
      sign_in(Fabricate(:admin))

      get "/styleguide/design-variables.json"

      expect(response.status).to eq(200)
      variables = response.parsed_body["design_variables"].index_by { |variable| variable["name"] }
      expect(variables["--d-border-radius"]).to include(
        "type" => "length",
        "scope" => "root",
        "default" => "4px",
        "editable" => true,
        "min_px" => 0,
        "max_px" => 32,
      )
      not_editable = variables.values.reject { |variable| variable["editable"] }
      expect(not_editable).to be_present
      expect(not_editable).to all(include("reason" => be_present))
      expect(response.parsed_body["palette_variables"]).to include("--primary", "--tertiary")
    end

    it "is only for people who can see the styleguide" do
      sign_in(Fabricate(:user))
      get "/styleguide/design-variables.json"
      expect(response.status).to eq(404)

      SiteSetting.styleguide_enabled = false
      sign_in(Fabricate(:admin))
      get "/styleguide/design-variables.json"
      expect(response.status).to eq(404)
    end
  end
end
