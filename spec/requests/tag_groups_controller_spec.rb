# frozen_string_literal: true

RSpec.describe TagGroupsController do
  fab!(:user)

  describe "#index" do
    fab!(:tag_group)

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
      fab!(:admin)

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
    fab!(:tag)

    let(:everyone) { Group::AUTO_GROUPS[:everyone] }
    let(:staff) { Group::AUTO_GROUPS[:staff] }

    let(:full) { TagGroupPermission.permission_types[:full] }
    let(:readonly) { TagGroupPermission.permission_types[:readonly] }

    describe "when limit params is invalid" do
      include_examples "invalid limit params",
                       "/tag_groups/filter/search.json",
                       SiteSetting.max_tag_search_results
    end

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

  describe "#create" do
    fab!(:admin)

    fab!(:tag1) { Fabricate(:tag) }
    fab!(:tag2) { Fabricate(:tag) }

    before { sign_in(admin) }

    it "should create a tag group and log the creation" do
      post "/tag_groups.json",
           params: {
             tag_group: {
               name: "test_tag_group_log",
               tag_names: [tag1.name, tag2.name],
             },
           }

      expect(response.status).to eq(200)

      expect(TagGroup.last.id).to eq(response.parsed_body["tag_group"]["id"])

      expect(UserHistory.last).to have_attributes(
        acting_user_id: admin.id,
        action: UserHistory.actions[:tag_group_create],
        subject: "test_tag_group_log",
        new_value: response.parsed_body["tag_group"].to_json,
      )
    end
  end

  describe "#delete" do
    fab!(:admin)

    fab!(:tag1) { Fabricate(:tag) }
    fab!(:tag2) { Fabricate(:tag) }
    fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2]) }

    before { sign_in(admin) }

    it "should delete the tag group and log the deletion" do
      previous_value = TagGroupSerializer.new(tag_group).to_json(root: false)

      delete "/tag_groups/#{tag_group.id}.json"

      expect(response.status).to eq(200)

      expect(TagGroup.find_by(id: tag_group.id)).to eq(nil)

      expect(UserHistory.last).to have_attributes(
        acting_user_id: admin.id,
        action: UserHistory.actions[:tag_group_destroy],
        subject: tag_group.name,
        previous_value:,
      )
    end
  end

  describe "#update" do
    fab!(:admin)

    fab!(:tag1) { Fabricate(:tag) }
    fab!(:tag2) { Fabricate(:tag) }
    fab!(:tag3) { Fabricate(:tag) }
    fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2]) }

    before { sign_in(admin) }

    it "should update the tag group and log the modification" do
      previous_value = TagGroupSerializer.new(tag_group).to_json(root: false)

      put "/tag_groups/#{tag_group.id}.json",
          params: {
            tag_group: {
              tag_group: {
                name: "test_tag_group_new_name",
                tag_names: [tag2.name, tag3.name],
              },
            },
          }

      expect(response.status).to eq(200)

      expect(UserHistory.last).to have_attributes(
        acting_user_id: admin.id,
        action: UserHistory.actions[:tag_group_change],
        subject: tag_group.name,
        previous_value:,
        new_value: response.parsed_body["tag_group"].to_json,
      )
    end
  end
end
