# frozen_string_literal: true

RSpec.describe Styleguide::StyleguideController do
  before { SiteSetting.styleguide_enabled = true }

  describe "#index" do
    context "when styleguide_allowed_groups is set to everyone" do
      before { SiteSetting.styleguide_allowed_groups = Group::AUTO_GROUPS[:everyone] }

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
        expect(response.status).to eq(403)
      end

      it "returns 403 for regular users" do
        sign_in(Fabricate(:user))
        get "/styleguide"
        expect(response.status).to eq(403)
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
        expect(response.status).to eq(403)
      end

      it "returns 403 for users not in the group" do
        sign_in(non_member)
        get "/styleguide"
        expect(response.status).to eq(403)
      end

      it "allows access for users in the group" do
        sign_in(group_member)
        get "/styleguide"
        expect(response.status).to eq(200)
      end
    end
  end
end
