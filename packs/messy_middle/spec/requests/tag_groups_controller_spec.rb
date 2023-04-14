# frozen_string_literal: true

RSpec.describe TagGroupsController do
  fab!(:user) { Fabricate(:user) }

  describe "#index" do
    fab!(:tag_group) { Fabricate(:tag_group) }

    describe "for a non staff user" do
      it "should not be accessible" do
        get "/tag_groups.json"

        expect(response.status).to eq(404)

        sign_in(user)
        get "/tag_groups.json"

        expect(response.status).to eq(404)
      end
    end

    describe "for a staff user" do
      fab!(:admin) { Fabricate(:admin) }

      before { sign_in(admin) }

      it "should return the right response" do
        tag_group

        get "/tag_groups.json"

        expect(response.status).to eq(200)

        tag_groups = response.parsed_body["tag_groups"]

        expect(tag_groups.count).to eq(1)
        expect(tag_groups.first["id"]).to eq(tag_group.id)
      end
    end
  end

  describe "#search" do
    fab!(:tag) { Fabricate(:tag) }

    let(:everyone) { Group::AUTO_GROUPS[:everyone] }
    let(:staff) { Group::AUTO_GROUPS[:staff] }

    let(:full) { TagGroupPermission.permission_types[:full] }
    let(:readonly) { TagGroupPermission.permission_types[:readonly] }

    context "for anons" do
      it "returns the tag group with the associated tag names" do
        tag_group = tag_group_with_permission(everyone, readonly)
        tag_group2 = tag_group_with_permission(everyone, readonly)

        get "/tag_groups/filter/search.json"
        expect(response.status).to eq(200)

        results = JSON.parse(response.body, symbolize_names: true).fetch(:results)

        expect(results).to contain_exactly(
          { name: tag_group.name, tag_names: [tag.name] },
          { name: tag_group2.name, tag_names: [tag.name] },
        )
      end

      it "returns an empty array if the tag group is private" do
        tag_group_with_permission(staff, full)

        get "/tag_groups/filter/search.json"
        expect(response.status).to eq(200)

        results = JSON.parse(response.body, symbolize_names: true).fetch(:results)

        expect(results).to be_empty
      end
    end

    context "for regular users" do
      before { sign_in(user) }

      it "returns the tag group with the associated tag names" do
        tag_group = tag_group_with_permission(everyone, readonly)

        get "/tag_groups/filter/search.json"
        expect(response.status).to eq(200)

        results = JSON.parse(response.body, symbolize_names: true).fetch(:results)

        expect(results.first[:name]).to eq(tag_group.name)
        expect(results.first[:tag_names]).to contain_exactly(tag.name)
      end

      it "returns an empty array if the tag group is private" do
        tag_group_with_permission(staff, full)

        get "/tag_groups/filter/search.json"
        expect(response.status).to eq(200)

        results = JSON.parse(response.body, symbolize_names: true).fetch(:results)

        expect(results).to be_empty
      end

      it "finds exact case-insensitive matches using the `names` param" do
        tag_group_with_permission(everyone, readonly, name: "Whee")
        tag_group_with_permission(everyone, readonly, name: "Whee Two")

        get "/tag_groups/filter/search.json", params: { names: ["WHEE"] }
        expect(response.status).to eq(200)

        results = JSON.parse(response.body, symbolize_names: true).fetch(:results)

        expect(results.count).to eq(1)
        expect(results.first[:name]).to eq("Whee")
      end

      it "finds partial matches using the `q` param" do
        tag_group_with_permission(everyone, readonly, name: "Whee")
        tag_group_with_permission(everyone, readonly, name: "Woop")
        tag_group_with_permission(everyone, readonly, name: "Hoop")

        get "/tag_groups/filter/search.json", params: { q: "oop" }
        expect(response.status).to eq(200)

        results = JSON.parse(response.body, symbolize_names: true).fetch(:results)

        expect(results.count).to eq(2)
        expect(results.first[:name]).to eq("Hoop")
        expect(results.last[:name]).to eq("Woop")
      end
    end

    def tag_group_with_permission(auto_group, permission_type, name: nil)
      options = { tags: [tag] }
      options.merge!({ name: name }) if name

      Fabricate(:tag_group, options).tap do |tag_group|
        tag_group.permissions = [[auto_group, permission_type]]
        tag_group.save!
      end
    end
  end
end
