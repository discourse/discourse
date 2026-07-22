# frozen_string_literal: true

RSpec.describe Admin::Config::CategoryManagementController do
  fab!(:admin)

  describe "#categories" do
    before { sign_in(admin) }

    around do |example|
      types = Categories::TypeRegistry.all.dup
      owners = types.keys.index_with { |type_id| Categories::TypeRegistry.owner(type_id) }

      example.run
    ensure
      Categories::TypeRegistry.instance_variable_set(:@types, types)
      Categories::TypeRegistry.instance_variable_set(:@owners, owners)
    end

    it "returns discussion categories with hierarchy data" do
      SiteSetting.max_category_nesting = 3

      parent = Fabricate(:category, name: "Knowledge", slug: "knowledge")
      child = Fabricate(:category, name: "Guides", slug: "guides", parent_category: parent)
      grandchild = Fabricate(:category, name: "API", slug: "api", parent_category: child)

      get "/admin/config/category-management/categories.json",
          params: {
            type: "discussion",
            filter: "API",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["categories"]).to contain_exactly(
        a_hash_including(
          "id" => grandchild.id,
          "badge_chain" => [
            a_hash_including("id" => parent.id, "name" => "Knowledge"),
            a_hash_including("id" => child.id, "name" => "Guides"),
            a_hash_including("id" => grandchild.id, "name" => "API"),
          ],
          "edit_url" => "/c/knowledge/guides/api/edit/general",
        ),
      )
    end

    it "returns all, discussion-only, and typed categories" do
      typed_category = Fabricate(:category, name: "Virtual all typed", slug: "virtual-all-typed")
      discussion_category =
        Fabricate(:category, name: "Virtual all discussion", slug: "virtual-all-discussion")

      fake_type =
        Class.new(Categories::Types::Base) do
          class << self
            attr_accessor :matching_category_ids

            def type_id
              :test_admin_type
            end

            def category_matches?(category)
              matching_category_ids.include?(category.id)
            end

            def find_matches
              Category.where(id: matching_category_ids)
            end
          end
        end
      fake_type.matching_category_ids = [typed_category.id]
      Categories::TypeRegistry.register(fake_type)

      get "/admin/config/category-management/categories.json", params: { type: "test_admin_type" }

      expect(response.status).to eq(200)
      expect(
        response.parsed_body["categories"].map { |category| category["id"] },
      ).to contain_exactly(typed_category.id)

      get "/admin/config/category-management/categories.json",
          params: {
            type: "all",
            filter: "Virtual all",
          }

      expect(
        response.parsed_body["categories"].map { |category| category["id"] },
      ).to contain_exactly(discussion_category.id, typed_category.id)
      expect(
        response.parsed_body["categories"].find { |category| category["id"] == typed_category.id }[
          "category_types"
        ],
      ).to contain_exactly(
        a_hash_including("id" => "discussion", "name" => "Discussion"),
        a_hash_including("id" => "test_admin_type", "name" => "Test Admin Type"),
      )

      get "/admin/config/category-management/categories.json",
          params: {
            type: "discussion",
            filter: "Virtual all",
          }

      expect(
        response.parsed_body["categories"].map { |category| category["id"] },
      ).to contain_exactly(discussion_category.id)
    end

    it "filters categories by hashtag reference" do
      parent = Fabricate(:category, name: "Project parent", slug: "project-parent")
      child =
        Fabricate(:category, name: "Project child", slug: "project-child", parent_category: parent)

      get "/admin/config/category-management/categories.json",
          params: {
            type: "discussion",
            filter: "#project-parent::project-child",
          }

      expect(response.status).to eq(200)
      expect(
        response.parsed_body["categories"].map { |category| category["id"] },
      ).to contain_exactly(child.id)
    end

    it "orders categories by name and paginates results" do
      third = Fabricate(:category, name: "Paginated category Charlie")
      first = Fabricate(:category, name: "Paginated category Alpha")
      second = Fabricate(:category, name: "Paginated category Bravo")

      get "/admin/config/category-management/categories.json",
          params: {
            type: "discussion",
            filter: "Paginated category",
            per_page: 2,
          }

      expect(response.parsed_body).to include(
        "categories" => [a_hash_including("id" => first.id), a_hash_including("id" => second.id)],
        "has_more" => true,
      )

      get "/admin/config/category-management/categories.json",
          params: {
            type: "discussion",
            filter: "Paginated category",
            per_page: 2,
            page: 1,
          }

      expect(response.parsed_body).to include(
        "categories" => [a_hash_including("id" => third.id)],
        "has_more" => false,
      )
    end

    it "filters categories by visibility" do
      public_category = Fabricate(:category, name: "Visible public category")
      restricted_category =
        Fabricate(:private_category, group: Group[:admins], name: "Visible restricted category")

      get "/admin/config/category-management/categories.json",
          params: {
            type: "discussion",
            filter: "Visible",
            visibility: "public",
          }

      expect(
        response.parsed_body["categories"].map { |category| category["id"] },
      ).to contain_exactly(public_category.id)

      get "/admin/config/category-management/categories.json",
          params: {
            type: "discussion",
            filter: "Visible",
            visibility: "restricted",
          }

      expect(
        response.parsed_body["categories"].map { |category| category["id"] },
      ).to contain_exactly(restricted_category.id)
    end
  end
end
