# frozen_string_literal: true

RSpec.describe "JSON:API query relationships", type: :request do
  fab!(:admin)
  fab!(:groups) { Fabricate.times(61, :group) }
  fab!(:unrelated_group, :group)

  let!(:query) { Fabricate(:query, hidden:) }
  let(:hidden) { false }
  let(:user) { admin }
  let(:headers) { { "HTTP_API_VERSION" => JsonApiKit::Timeline.current.to_s } }
  let(:query_path) { "/api/data-explorer/queries/#{query.id}" }
  let(:first_page) { JSON.parse(response.body) }
  let(:second_page) { JSON.parse(response.body) }
  let(:third_page) { JSON.parse(response.body) }
  let(:expected_ids) { groups.map(&:id).sort.map(&:to_s) }

  before do
    SiteSetting.data_explorer_enabled = true
    host! Discourse.current_hostname
    sign_in(user)
    query.groups = groups
  end

  describe "GET /relationships/groups" do
    let(:relationship) { first_page.dig("data", "relationships", "groups") }
    let(:first_page_ids) { relationship.fetch("data").map { it.fetch("id") } }
    let(:second_page_ids) { second_page.fetch("data").map { it.fetch("id") } }
    let(:third_page_ids) { third_page.fetch("data").map { it.fetch("id") } }

    before { get(query_path, headers:, params: { include: "groups" }) }

    it "continues the embedded group membership through every page", :aggregate_failures do
      expect(first_page_ids.size).to eq(25)

      get(relationship.dig("links", "next"), headers:)

      expect(second_page_ids.size).to eq(25)

      get(second_page.dig("links", "next"), headers:)

      expect(first_page_ids + second_page_ids + third_page_ids).to eq(expected_ids)
      expect(third_page.fetch("links")).to include("next" => nil)
    end
  end

  describe "GET /groups" do
    let(:group_data) do
      groups
        .sort_by(&:id)
        .first(25)
        .map do |group|
          a_hash_including(
            "type" => "groups",
            "id" => group.id.to_s,
            "attributes" => {
              "name" => group.name,
            },
          )
        end
    end

    before { get("#{query_path}/groups", headers:) }

    it "returns the query's group resources" do
      expect(first_page.fetch("data")).to match(group_data)
    end

    it "provides a working group self link" do
      get(first_page.dig("data", 0, "links", "self"), headers:)

      expect(JSON.parse(response.body).fetch("data")).to include(
        "type" => "groups",
        "id" => expected_ids.first,
      )
    end

    context "when the query is hidden" do
      let(:hidden) { true }

      it { expect(response).to have_http_status(:not_found) }
    end

    context "when the query is a default query" do
      let!(:query) do
        DiscourseDataExplorer::Query
          .find(-1)
          .tap do |query|
            query.hidden = hidden
            query.save!
          end
      end

      it "returns the query's group resources" do
        expect(first_page.fetch("data")).to match(group_data)
      end

      context "when the query is hidden" do
        let(:hidden) { true }

        it { expect(response).to have_http_status(:not_found) }
      end
    end

    context "when the user is not an admin" do
      fab!(:visitor, :user)

      let(:user) { visitor }

      it { expect(response).to have_http_status(:forbidden) }
    end
  end
end
