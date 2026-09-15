# frozen_string_literal: true

RSpec.describe JsonApiKit::Document::RelationshipObject do
  subject(:relationship_object) { described_class.new(linkage, client:, owner:, name:) }

  fab!(:author, :user)
  fab!(:topic)

  let(:guardian) { Guardian.new }
  let(:glossary) { JsonApiKit::Glossary.kit }
  let(:client) { JsonApiKit::Client.new(guardian:, glossary:, urls:) }
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
  let(:name) { "posts" }
  let(:linkage) { JsonApiKit::Linkage::ToOne.new([record]) }
  let(:relationship_url) { "https://example.com/api/topics/#{topic.id}/relationships/posts" }
  let(:related_url) { "https://example.com/api/topics/#{topic.id}/posts" }

  describe "#to_h" do
    context "when the current relationship name has several words" do
      let(:name) { "ordered_posts" }
      let(:glossary) { JsonApiKit::Glossary.resource(JsonApiKit::Timeline::FIRST_RELEASE) }
      let(:version_change) do
        Class
          .new(JsonApiKit::VersionChange) do
            resource :topics do
              renamed_relationship from: :archived_posts, to: :ordered_posts
            end
          end
          .new(__FILE__)
      end

      before do
        allow(JsonApiKit::VersionChanges.core).to receive(:after).and_return([version_change])
      end

      it "uses the current names with kebab casing in URLs" do
        expect(relationship_object.to_h[:links]).to eq(
          self: "https://example.com/api/topics/#{topic.id}/relationships/ordered-posts",
          related: "https://example.com/api/topics/#{topic.id}/ordered-posts",
        )
      end
    end

    context "when the type has a historical name" do
      let(:glossary) { JsonApiKit::Glossary.resource(JsonApiKit::Timeline::FIRST_RELEASE) }
      let(:version_change) do
        Class
          .new(JsonApiKit::VersionChange) { renamed_type from: :topic_authors, to: :users }
          .new(__FILE__)
      end

      before do
        allow(JsonApiKit::VersionChanges.core).to receive(:after).and_return([version_change])
      end

      it "translates the linkage type" do
        expect(relationship_object.to_h[:data]).to eq(type: "topicAuthors", id: author.id.to_s)
      end

      it "keeps the record identity in the current vocabulary" do
        relationship_object.to_h
        expect(record.identity.to_h).to eq(type: "users", id: author.id.to_s)
      end
    end

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
