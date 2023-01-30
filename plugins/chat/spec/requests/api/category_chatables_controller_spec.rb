# frozen_string_literal: true

require "rails_helper"

describe Chat::Api::CategoryChatablesController do
  describe "#access_by_category" do
    fab!(:group) { Fabricate(:group) }
    fab!(:private_category) { Fabricate(:private_category, group: group) }

    context "when signed in as an admin" do
      fab!(:admin) { Fabricate(:admin) }

      before { sign_in(admin) }

      it "returns a list with the group names that could access a chat channel" do
        readonly_group = Fabricate(:group)
        Fabricate(
          :category_group,
          category: private_category,
          group: readonly_group,
          permission_type: CategoryGroup.permission_types[:readonly],
        )
        create_post_group = Fabricate(:group)
        create_post_category_group =
          Fabricate(
            :category_group,
            category: private_category,
            group: create_post_group,
            permission_type: CategoryGroup.permission_types[:create_post],
          )
        get "/chat/api/category-chatables/#{private_category.id}/permissions"

        expect(response.parsed_body["allowed_groups"]).to contain_exactly(
          "@#{group.name}",
          "@#{create_post_group.name}",
        )
        expect(response.parsed_body["members_count"]).to eq(0)
        expect(response.parsed_body["private"]).to eq(true)
      end

      it "doesn't return group names from other categories" do
        a_member = Fabricate(:user)
        group_2 = Fabricate(:group)
        group_2.add(a_member)
        category_2 = Fabricate(:private_category, group: group_2)

        get "/chat/api/category-chatables/#{category_2.id}/permissions"

        expect(response.parsed_body["allowed_groups"]).to contain_exactly("@#{group_2.name}")
        expect(response.parsed_body["members_count"]).to eq(1)
        expect(response.parsed_body["private"]).to eq(true)
      end

      it "returns the everyone group when a category is public" do
        Fabricate(:user)
        category_2 = Fabricate(:category)
        everyone_group = Group.find(Group::AUTO_GROUPS[:everyone])

        get "/chat/api/category-chatables/#{category_2.id}/permissions"

        expect(response.parsed_body["allowed_groups"]).to contain_exactly("@#{everyone_group.name}")
        expect(response.parsed_body["members_count"]).to be_nil
        expect(response.parsed_body["private"]).to eq(false)
      end

      it "includes the number of users with access" do
        number_of_users = 3
        number_of_users.times { group.add(Fabricate(:user)) }

        get "/chat/api/category-chatables/#{private_category.id}/permissions"

        expect(response.parsed_body["allowed_groups"]).to contain_exactly("@#{group.name}")
        expect(response.parsed_body["members_count"]).to eq(number_of_users)
        expect(response.parsed_body["private"]).to eq(true)
      end

      it "returns a 404 when passed an invalid category" do
        get "/chat/api/category-chatables/-99/permissions"

        expect(response.status).to eq(404)
      end
    end

    context "as anon" do
      it "returns a 404" do
        get "/chat/api/category-chatables/#{private_category.id}/permissions"

        expect(response.status).to eq(404)
      end
    end

    context "when signed in as a regular user" do
      fab!(:user) { Fabricate(:user) }

      before { sign_in(user) }

      it "returns a 404" do
        get "/chat/api/category-chatables/#{private_category.id}/permissions"

        expect(response.status).to eq(404)
      end
    end
  end
end
