# frozen_string_literal: true

require "rails_helper"

describe HashtagsController do
  fab!(:category) { Fabricate(:category) }
  fab!(:tag) { Fabricate(:tag) }

  fab!(:group) { Fabricate(:group) }
  fab!(:private_category) { Fabricate(:private_category, group: group) }

  fab!(:hidden_tag) { Fabricate(:tag, name: "hidden") }
  let(:tag_group) { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name]) }

  before do
    SiteSetting.tagging_enabled = true
    tag_group
  end

  describe "#check" do
    context "when logged in" do
      context "as regular user" do
        before do
          sign_in(Fabricate(:user))
        end

        it "returns only valid categories and tags" do
          get "/hashtags.json", params: { slugs: [category.slug, private_category.slug, "none", tag.name, hidden_tag.name] }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq(
            "categories" => { category.slug => category.url },
            "tags" => { tag.name => tag.full_url }
          )
        end

        it "does not return restricted categories or hidden tags" do
          get "/hashtags.json", params: { slugs: [private_category.slug, hidden_tag.name] }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq("categories" => {}, "tags" => {})
        end
      end

      context "as admin" do
        fab!(:admin) { Fabricate(:admin) }

        before do
          sign_in(admin)
        end

        it "returns restricted categories and hidden tags" do
          group.add(admin)

          get "/hashtags.json", params: { slugs: [private_category.slug, hidden_tag.name] }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq(
            "categories" => { private_category.slug => private_category.url },
            "tags" => { hidden_tag.name => hidden_tag.full_url }
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

          get "/hashtags.json", params: {
            slugs: [
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
          expect(response.parsed_body["categories"]).to eq(
            "foo" => foo.url,
            "foo:bar" => foobar.url,
            "bar:baz" => foobarbaz.id < quxbarbaz.id ? foobarbaz.url : quxbarbaz.url,
            "qux" => qux.url,
            "qux:bar" => quxbar.url
          )
        end
      end
    end

    context "when not logged in" do
      it "returns invalid access" do
        get "/hashtags.json", params: { slugs: [] }
        expect(response.status).to eq(403)
      end
    end
  end
end
