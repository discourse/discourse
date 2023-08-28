# frozen_string_literal: true

RSpec.describe HashtagsController do
  fab!(:category) { Fabricate(:category, name: "Random", slug: "random") }
  fab!(:tag) { Fabricate(:tag, name: "bug") }

  fab!(:group) { Fabricate(:group) }
  fab!(:private_category) do
    Fabricate(:private_category, group: group, name: "Staff", slug: "staff")
  end

  fab!(:hidden_tag) { Fabricate(:tag, name: "hidden") }
  let(:tag_group) do
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
  end

  before do
    SiteSetting.tagging_enabled = true
    tag_group
  end

  describe "#lookup" do
    context "when logged in" do
      context "as regular user" do
        before { sign_in(Fabricate(:user)) }

        it "returns only valid categories and tags" do
          get "/hashtags.json",
              params: {
                slugs: [category.slug, private_category.slug, "none", tag.name, hidden_tag.name],
                order: %w[category tag],
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq(
            {
              "category" => [
                {
                  "relative_url" => category.url,
                  "text" => category.name,
                  "description" => nil,
                  "icon" => "folder",
                  "type" => "category",
                  "ref" => category.slug,
                  "slug" => category.slug,
                  "id" => category.id,
                },
              ],
              "tag" => [
                {
                  "relative_url" => tag.url,
                  "text" => tag.name,
                  "description" => nil,
                  "icon" => "tag",
                  "type" => "tag",
                  "ref" => tag.name,
                  "slug" => tag.name,
                  "secondary_text" => "x0",
                  "id" => tag.id,
                },
              ],
            },
          )
        end

        it "handles tags with the ::tag type suffix" do
          get "/hashtags.json", params: { slugs: ["#{tag.name}::tag"], order: %w[category tag] }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq(
            {
              "category" => [],
              "tag" => [
                {
                  "relative_url" => tag.url,
                  "text" => tag.name,
                  "description" => nil,
                  "icon" => "tag",
                  "type" => "tag",
                  "ref" => "#{tag.name}::tag",
                  "slug" => tag.name,
                  "secondary_text" => "x0",
                  "id" => tag.id,
                },
              ],
            },
          )
        end

        it "does not return restricted categories or hidden tags" do
          get "/hashtags.json",
              params: {
                slugs: [private_category.slug, hidden_tag.name],
                order: %w[category tag],
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq({ "category" => [], "tag" => [] })
        end
      end

      context "as admin" do
        fab!(:admin) { Fabricate(:admin) }

        before { sign_in(admin) }

        it "returns restricted categories and hidden tags" do
          group.add(admin)

          get "/hashtags.json",
              params: {
                slugs: [private_category.slug, hidden_tag.name],
                order: %w[category tag],
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq(
            {
              "category" => [
                {
                  "relative_url" => private_category.url,
                  "text" => private_category.name,
                  "description" => nil,
                  "icon" => "folder",
                  "type" => "category",
                  "ref" => private_category.slug,
                  "slug" => private_category.slug,
                  "id" => private_category.id,
                },
              ],
              "tag" => [
                {
                  "relative_url" => hidden_tag.url,
                  "text" => hidden_tag.name,
                  "description" => nil,
                  "icon" => "tag",
                  "type" => "tag",
                  "ref" => hidden_tag.name,
                  "slug" => hidden_tag.name,
                  "secondary_text" => "x0",
                  "id" => hidden_tag.id,
                },
              ],
            },
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
          foobarbaz =
            Fabricate(:category_with_definition, slug: "baz", parent_category_id: foobar.id)

          qux = Fabricate(:category_with_definition, slug: "qux")
          quxbar = Fabricate(:category_with_definition, slug: "bar", parent_category_id: qux.id)
          quxbarbaz =
            Fabricate(:category_with_definition, slug: "baz", parent_category_id: quxbar.id)

          invalid_slugs = [":"]
          child_slugs = %w[bar baz]
          deeply_nested_slugs = %w[foo:bar:baz qux:bar:baz]
          get "/hashtags.json",
              params: {
                slugs:
                  invalid_slugs + child_slugs + deeply_nested_slugs +
                    %w[foo foo:bar bar:baz qux qux:bar],
                order: %w[category tag],
              }

          expect(response.status).to eq(200)
          found_categories = response.parsed_body["category"]
          expect(found_categories.map { |c| c["ref"] }).to match_array(
            %w[foo foo:bar bar:baz qux qux:bar],
          )
          expect(found_categories.find { |c| c["ref"] == "foo" }["relative_url"]).to eq(foo.url)
          expect(found_categories.find { |c| c["ref"] == "foo:bar" }["relative_url"]).to eq(
            foobar.url,
          )
          expect(found_categories.find { |c| c["ref"] == "bar:baz" }["relative_url"]).to eq(
            foobarbaz.url,
          )
          expect(found_categories.find { |c| c["ref"] == "qux" }["relative_url"]).to eq(qux.url)
          expect(found_categories.find { |c| c["ref"] == "qux:bar" }["relative_url"]).to eq(
            quxbar.url,
          )
        end
      end
    end

    context "when not logged in" do
      it "returns invalid access" do
        get "/hashtags.json", params: { slugs: [], order: %w[category tag] }
        expect(response.status).to eq(403)
      end
    end
  end

  describe "#search" do
    fab!(:tag_2) { Fabricate(:tag, name: "random") }

    context "when logged in" do
      before { sign_in(Fabricate(:user)) }

      it "returns the found category and then tag" do
        get "/hashtags/search.json", params: { term: "rand", order: %w[category tag] }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"]).to eq(
          [
            {
              "relative_url" => category.url,
              "text" => category.name,
              "description" => nil,
              "icon" => "folder",
              "type" => "category",
              "ref" => category.slug,
              "slug" => category.slug,
              "id" => category.id,
            },
            {
              "relative_url" => tag_2.url,
              "text" => tag_2.name,
              "description" => nil,
              "icon" => "tag",
              "type" => "tag",
              "ref" => "#{tag_2.name}::tag",
              "slug" => tag_2.name,
              "secondary_text" => "x0",
              "id" => tag_2.id,
            },
          ],
        )
      end

      it "does not return hidden and restricted categories/tags" do
        get "/hashtags/search.json", params: { term: "staff", order: %w[category tag] }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"]).to eq([])

        get "/hashtags/search.json", params: { term: "hidden", order: %w[category tag] }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"]).to eq([])
      end
    end

    context "when logged in as admin" do
      before { sign_in(Fabricate(:admin)) }

      it "returns hidden and restricted categories/tags" do
        get "/hashtags/search.json", params: { term: "staff", order: %w[category tag] }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"]).to eq(
          [
            {
              "relative_url" => private_category.url,
              "text" => private_category.name,
              "description" => nil,
              "icon" => "folder",
              "type" => "category",
              "ref" => private_category.slug,
              "slug" => private_category.slug,
              "id" => private_category.id,
            },
          ],
        )

        get "/hashtags/search.json", params: { term: "hidden", order: %w[category tag] }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"]).to eq(
          [
            {
              "relative_url" => hidden_tag.url,
              "text" => hidden_tag.name,
              "description" => nil,
              "icon" => "tag",
              "type" => "tag",
              "ref" => "#{hidden_tag.name}",
              "slug" => hidden_tag.name,
              "secondary_text" => "x0",
              "id" => hidden_tag.id,
            },
          ],
        )
      end
    end

    context "when not logged in" do
      it "returns invalid access" do
        get "/hashtags/search.json", params: { term: "rand", order: %w[category tag] }
        expect(response.status).to eq(403)
      end
    end
  end
end
