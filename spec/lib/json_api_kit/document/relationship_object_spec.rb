# frozen_string_literal: true

RSpec.describe JsonApiKit::Document::RelationshipObject do
  subject(:relationship_object) { described_class.new(linkage, urls:, owner:, name: "posts") }

  fab!(:author, :user)
  fab!(:topic)

  let(:guardian) { Guardian.new }
  let(:urls) do
    JsonApiKit::Urls.new(base: "https://example.com/api", current: "https://example.com/api/topics")
  end
  let(:users_resource) do
    Class.new(JsonApiKit::Resource) do
      model User
      type :users
      attribute :username
    end
  end
  let(:topics_resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
    end
  end
  let(:record) do
    JsonApiKit::Record.new(
      JsonApiKit::Pagination::Row.new(record: author, segment: nil),
      users_resource.fields(guardian:),
      type: "users",
    )
  end
  let(:owner) do
    JsonApiKit::Record.new(
      JsonApiKit::Pagination::Row.new(record: topic, segment: nil),
      topics_resource.fields(guardian:),
      type: "topics",
      namespace:,
    )
  end
  let(:namespace) { nil }
  let(:linkage) { JsonApiKit::Linkage::ToOne.new([record]) }
  let(:relationship_url) { "https://example.com/api/topics/#{topic.id}/relationships/posts" }
  let(:related_url) { "https://example.com/api/topics/#{topic.id}/posts" }

  describe "#to_h" do
    it "renders the record it links to" do
      expect(relationship_object.to_h[:data]).to eq(type: "users", id: author.id.to_s)
    end

    it "renders the relationship link and the related link" do
      expect(relationship_object.to_h[:links]).to eq(self: relationship_url, related: related_url)
    end

    context "with a namespace" do
      let(:namespace) { "data-explorer" }

      it "renders both links under it" do
        expect(relationship_object.to_h[:links]).to eq(
          self: "https://example.com/api/data-explorer/topics/#{topic.id}/relationships/posts",
          related: "https://example.com/api/data-explorer/topics/#{topic.id}/posts",
        )
      end
    end

    context "when the relationship holds a page of records" do
      let(:page) do
        JsonApiKit::Records::Page.new(JsonApiKit::Records.new([record]), "read-on-here")
      end
      let(:linkage) { JsonApiKit::Linkage::ToMany.new(page, previous_page: "read-back-here") }

      it "renders a page link at each end" do
        expect(relationship_object.to_h[:links]).to eq(
          self: relationship_url,
          related: related_url,
          prev: "#{relationship_url}?page[before]=read-back-here",
          next: "#{relationship_url}?page[after]=read-on-here",
        )
      end
    end
  end
end
