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
        before do
          SiteSetting.max_category_nesting = 3
          sign_in(Fabricate(:user))
        end

        it "works" do
          foo = Fabricate(:category_with_definition, slug: "foo")
          foobar = Fabricate(:category_with_definition, slug: "bar", parent_category_id: foo.id)
          foobarbaz = Fabricate(:category_with_definition, slug: "baz", parent_category_id: foobar.id)

          qux = Fabricate(:category_with_definition, slug: "qux")
          quxbar = Fabricate(:category_with_definition, slug: "bar", parent_category_id: qux.id)
          quxbarbaz = Fabricate(:category_with_definition, slug: "baz", parent_category_id: quxbar.id)

          get "/category_hashtags/check.json", params: {
            category_slugs: [
              ":", # should not work
              "foo",
              "bar", # should not work
              "baz", # should not work
              "foo:bar",
              "bar:baz",
              "foo:bar:baz", # should not work
              "qux",
              "qux:bar",
              "qux:bar:baz" # should not work
            ]
          }

          expect(response.status).to eq(200)
          expect(response.parsed_body["valid"]).to contain_exactly(
            { "slug" => "foo",     "url" => foo.url },
            { "slug" => "foo:bar", "url" => foobar.url },
            { "slug" => "bar:baz", "url" => foobarbaz.id < quxbarbaz.id ? foobarbaz.url : quxbarbaz.url },
            { "slug" => "qux",     "url" => qux.url },
            { "slug" => "qux:bar", "url" => quxbar.url }
          )
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
