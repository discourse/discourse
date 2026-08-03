# frozen_string_literal: true

RSpec.describe JsonApiKit::Document::ResourceObject do
  subject(:resource_object) { described_class.new(record, urls:, meta:) }

  fab!(:topic) { Fabricate(:topic, title: "A row a document renders") }

  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      attribute :title
    end
  end
  let(:fields) { resource.fields }
  let(:row) { JsonApiKit::Pagination::Row.new(record: topic, segment: nil) }
  let(:record) { JsonApiKit::Record.new(row, fields, type: "topics") }
  let(:meta) { {} }
  let(:urls) do
    JsonApiKit::Urls.new(base: "https://example.com/api", current: "https://example.com/api/topics")
  end

  describe "#to_h" do
    it "renders the type, the id and the attributes" do
      expect(resource_object.to_h).to eq(
        type: "topics",
        id: topic.id.to_s,
        attributes: {
          "title" => topic.title,
        },
        links: {
          self: "https://example.com/api/topics/#{topic.id}",
        },
      )
    end

    context "when a caller gives it meta" do
      let(:meta) { { page: { cursor: "the-cursor" } } }

      it "renders the meta" do
        expect(resource_object.to_h[:meta]).to eq(page: { cursor: "the-cursor" })
      end
    end

    context "when the record holds no attribute" do
      let(:fields) { resource.fields(["secrets"]) }

      it "renders no attributes" do
        expect(resource_object.to_h).not_to have_key(:attributes)
      end
    end

    context "when the record holds a relationship" do
      let(:record) do
        JsonApiKit::Record.new(row, fields, type: "topics", relationships: { "user" => linkage })
      end
      let(:linkage) { JsonApiKit::Linkage::ToOne.new([author_record]) }
      let(:author_record) do
        JsonApiKit::Record.new(
          JsonApiKit::Pagination::Row.new(record: topic.user, segment: nil),
          users_resource.fields,
          type: "users",
        )
      end
      let(:users_resource) do
        Class.new(JsonApiKit::Resource) do
          model User
          type :users
        end
      end

      before { allow(JsonApiKit::Document::RelationshipObject).to receive(:new).and_call_original }

      it "renders the relationship under its own name" do
        expect(resource_object.to_h[:relationships].keys).to eq(["user"])
      end

      it "renders the linkage the record holds" do
        resource_object.to_h

        expect(JsonApiKit::Document::RelationshipObject).to have_received(:new).with(
          linkage,
          urls:,
          owner: record,
          name: "user",
        )
      end
    end

    context "when the record holds a relationship to many records" do
      fab!(:post)

      let(:posts_resource) do
        Class.new(JsonApiKit::Resource) do
          model Post
          type :posts
        end
      end
      let(:post_record) do
        JsonApiKit::Record.new(
          JsonApiKit::Pagination::Row.new(record: post, segment: nil),
          posts_resource.fields,
          type: "posts",
        )
      end
      let(:page) { JsonApiKit::Records::Page.new(JsonApiKit::Records.new([post_record]), nil) }
      let(:linkage) { JsonApiKit::Linkage::ToMany.new(page) }
      let(:record) do
        JsonApiKit::Record.new(row, fields, type: "topics", relationships: { "posts" => linkage })
      end

      it "renders every record it links to" do
        expect(resource_object.to_h[:relationships]["posts"][:data]).to eq(
          [{ type: "posts", id: post.id.to_s }],
        )
      end
    end
  end
end
