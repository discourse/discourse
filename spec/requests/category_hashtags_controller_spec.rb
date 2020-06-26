# frozen_string_literal: true

require "rails_helper"

describe CategoryHashtagsController do
  fab!(:category) { Fabricate(:category) }

  let(:group) { Fabricate(:group) }
  let(:private_category) { Fabricate(:private_category, group: group) }

  describe "#check" do
    context "when logged in" do
      context "as regular user" do
        before do
          sign_in(Fabricate(:user))
        end

        it "returns only valid categories" do
          get "/category_hashtags/check.json", params: { category_slugs: [category.slug, private_category.slug, "none"] }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq(
            "valid" => [{ "slug" => category.slug, "url" => category.url }]
          )
        end

        it "does not return restricted categories" do
          get "/category_hashtags/check.json", params: { category_slugs: [private_category.slug] }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq("valid" => [])
        end
      end

      context "as admin" do
        fab!(:admin) { Fabricate(:admin) }

        before do
          sign_in(admin)
        end

        it "returns restricted categories" do
          group.add(admin)

          get "/category_hashtags/check.json", params: { category_slugs: [private_category.slug] }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq(
            "valid" => [{ "slug" => private_category.slug, "url" => private_category.url }]
          )
        end
      end

      context "with sub-sub-categories" do
        let(:category) { Fabricate(:category_with_definition) }
        let(:subcategory) { Fabricate(:category_with_definition, parent_category_id: category.id) }
        let(:subsubcategory) { Fabricate(:category_with_definition, parent_category_id: subcategory.id) }

        before do
          SiteSetting.max_category_nesting = 3
          sign_in(Fabricate(:user))
        end

        it "works" do
          get "/category_hashtags/check.json", params: {
            category_slugs: [
              category.slug,
              "#{category.slug}:#{subcategory.slug}",
              "#{category.slug}:#{subcategory.slug}:#{subsubcategory.slug}",
              "#{category.slug}:#{subsubcategory.slug}",
              subcategory.slug,
              "#{subcategory.slug}:#{subsubcategory.slug}",
              subsubcategory.slug
            ]
          }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq("valid" => [
            { "slug" => category.slug, "url" => category.url },
            { "slug" => "#{category.slug}:#{subcategory.slug}", "url" => subcategory.url },
            { "slug" => "#{category.slug}:#{subcategory.slug}:#{subsubcategory.slug}", "url" => subsubcategory.url }
          ])
        end
      end
    end

    context "when not logged in" do
      it "returns invalid access" do
        get "/category_hashtags/check.json", params: { category_slugs: [] }
        expect(response.status).to eq(403)
      end
    end
  end
end
