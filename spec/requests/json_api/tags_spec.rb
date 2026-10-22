# frozen_string_literal: true

RSpec.describe "JSON:API tags", type: :request do
  fab!(:admin)
  fab!(:bug) { Fabricate(:tag, name: "bug", public_topic_count: 5, staff_topic_count: 7) }
  fab!(:debug) { Fabricate(:tag, name: "debugging", public_topic_count: 3, staff_topic_count: 3) }
  fab!(:enhancement) do
    Fabricate(:tag, name: "enhancement", public_topic_count: 1, staff_topic_count: 1)
  end
  fab!(:secret) { Fabricate(:tag, name: "secret", public_topic_count: 0, staff_topic_count: 9) }
  fab!(:staff_only) do
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [secret.name])
  end

  let(:query_parameters) { {} }
  let(:headers) { { "HTTP_API_VERSION" => JsonApiKit::Timeline.current.to_s } }

  before { SiteSetting.tagging_enabled = true }

  def parsed_body = JSON.parse(response.body)

  def names = parsed_body["data"].map { it["attributes"]["name"] }

  describe "GET /api/tags" do
    def fetch(params = query_parameters)
      get "/api/tags", headers:, params:
    end

    it "sends the tags an anonymous visitor can see, most used first, without staff counts" do
      fetch

      expect(response).to have_http_status(:ok)
      expect(names).to eq(%w[bug debugging enhancement])
      expect(parsed_body["data"].first).to eq(
        "type" => "tags",
        "id" => bug.id.to_s,
        "attributes" => {
          "name" => "bug",
          "slug" => bug.slug,
          "description" => nil,
          "publicTopicCount" => 5,
        },
        "links" => {
          "self" => "http://test.localhost/api/tags/#{bug.id}",
        },
      )
    end

    it "sends tags from staff-only groups and staff counts to an admin" do
      sign_in(admin)
      fetch

      expect(names).to contain_exactly("bug", "debugging", "enhancement", "secret")
      expect(parsed_body["data"].map { it["attributes"]["staffTopicCount"] }).to all(be_an(Integer))
    end

    it "finds the tag whose name is exactly the requested one, whatever the case" do
      fetch(filter: { name: "BUG" })
      expect(names).to eq(["bug"])

      fetch(filter: { name: "bu" })
      expect(parsed_body["data"]).to be_empty
    end

    it "keeps the tags the signed-in user put on their recent topics" do
      author = Fabricate(:user)
      Fabricate(:topic, user: author, tags: [debug])
      Fabricate(:topic, tags: [enhancement])
      sign_in(author)

      fetch(filter: { recentlyUsed: true })

      expect(names).to eq(["debugging"])
    end

    it "keeps no tags as recently used for an anonymous visitor" do
      fetch(filter: { recentlyUsed: true })

      expect(parsed_body["data"]).to be_empty
    end

    it "matches the term anywhere in the name, whatever the case" do
      fetch(filter: { term: "BUG" })

      expect(names).to contain_exactly("bug", "debugging")
    end

    it "matches the term against localized names in the current locale" do
      SiteSetting.content_localization_enabled = true
      Fabricate(:tag_localization, tag: enhancement, locale: "en", name: "funcionalidade")

      fetch(filter: { term: "funcional" })

      expect(names).to eq(["enhancement"])
    end

    it "reads a wildcard in the term as a plain character" do
      fetch(filter: { term: "%" })

      expect(parsed_body["data"]).to be_empty
    end

    it "keeps only the requested ids" do
      fetch(filter: { id: [bug.id, enhancement.id] })

      expect(names).to contain_exactly("bug", "enhancement")
    end

    it "leaves out the excluded ids" do
      fetch(filter: { exclude: [bug.id, enhancement.id] })

      expect(names).to eq(["debugging"])
    end

    it "leaves out synonyms and the tags that have synonyms when asked" do
      Fabricate(:tag, name: "defect", target_tag: bug)

      fetch(filter: { excludeSynonyms: true })
      expect(names).to contain_exactly("bug", "debugging", "enhancement")

      fetch(filter: { excludeHasSynonyms: true })
      expect(names).to contain_exactly("debugging", "enhancement", "defect")
    end

    it "includes the target of a synonym on request" do
      defect = Fabricate(:tag, name: "defect", target_tag: bug)

      fetch(filter: { term: "defect" }, include: "targetTag")

      expect(parsed_body["data"].sole.dig("relationships", "targetTag", "data")).to eq(
        "type" => "tags",
        "id" => bug.id.to_s,
      )
      expect(parsed_body["included"].map { it["id"] }).to eq([bug.id.to_s])
      expect(parsed_body["data"].sole["id"]).to eq(defect.id.to_s)
    end

    it "sorts by name and pages with cursors" do
      fetch(sort: "name", page: { size: 2 })
      expect(names).to eq(%w[bug debugging])

      get parsed_body["links"]["next"], headers: headers
      expect(names).to eq(["enhancement"])
      expect(parsed_body["links"]["next"]).to be_nil
    end

    it "refuses the staff count sort to an anonymous visitor, whose cursors would carry the counts" do
      fetch(sort: "-staffTopicCount")

      expect(response).to have_http_status(:bad_request)
      expect(parsed_body["errors"].sole["title"]).to eq("No such sort")
    end

    it "sorts staff by the staff count" do
      sign_in(admin)
      fetch(sort: "-staffTopicCount")

      expect(names).to eq(%w[secret bug debugging enhancement])
    end

    it "shows and sorts by the staff count for everyone when secure categories count for all" do
      SiteSetting.include_secure_categories_in_tag_counts = true

      fetch(sort: "-staffTopicCount")

      expect(names).to eq(%w[bug debugging enhancement])
      expect(parsed_body["data"].map { it["attributes"]["staffTopicCount"] }).to eq([7, 3, 1])
    end

    it "refuses the inputs of the applicable tags, which only that listing reads" do
      fetch(filter: { held: [bug.id] })

      expect(response).to have_http_status(:bad_request)
      expect(parsed_body["errors"].sole["title"]).to eq("No such filter")
    end
  end

  describe "GET /api/tags/applicable" do
    fab!(:user)
    fab!(:category_tag) { Fabricate(:tag, name: "category-tag", public_topic_count: 9) }
    fab!(:restricted) { Fabricate(:category, tags: [category_tag]) }

    before { sign_in(user) }

    def fetch(params = query_parameters)
      get "/api/tags/applicable", headers:, params:
    end

    it "sends the tags the user may apply to a topic without a category, with no input to opt in" do
      fetch

      expect(response).to have_http_status(:ok)
      expect(names).to eq(%w[bug debugging enhancement])
    end

    it "applies the restriction of the topic's category" do
      fetch(filter: { category: restricted.id })

      expect(names).to eq(["category-tag"])
    end

    it "leaves out the tags the topic already holds" do
      fetch(filter: { held: [bug.id] })

      expect(names).to eq(%w[debugging enhancement])
    end

    it "keeps the inputs in the link to the next page" do
      fetch(filter: { held: [bug.id] }, page: { size: 1 })
      expect(names).to eq(["debugging"])

      get parsed_body["links"]["next"], headers: headers
      expect(names).to eq(["enhancement"])
    end
  end
end
