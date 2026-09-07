# frozen_string_literal: true

RSpec.describe JsonApiKit::Document::Individual do
  subject(:document) { described_class.new(reading, urls:) }

  fab!(:topic) { Fabricate(:topic, title: "One record read on its own") }

  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      attribute :title
    end
  end
  let(:guardian) { Guardian.new }
  let(:urls) { JsonApiKit::Urls.new(base: "https://example.com/api", current:) }
  let(:current) { "https://example.com/api/topics/1" }
  let(:self_link) { { href: current, type: JsonApiKit::Pagination::Profile::MEDIA_TYPE } }
  let(:reading) { resource.find(topic.id, guardian:) }

  describe "#to_h" do
    it "renders the record as a document" do
      expect(document.to_h).to eq(
        data: {
          type: "topics",
          id: topic.id.to_s,
          attributes: {
            "title" => topic.title,
          },
          links: {
            self: "https://example.com/api/topics/#{topic.id}",
          },
        },
        included: [],
        links: {
          self: self_link,
        },
      )
    end

    context "when a request asks for a relationship" do
      let(:users_resource) do
        Class.new(JsonApiKit::Resource) do
          model User
          type :users
          attribute :username
        end
      end
      let(:resource) { Class.new(super()).tap { it.has_one(:user, resource: users_resource) } }
      let(:reading) { resource.find(topic.id, { include: %w[user] }, guardian:) }

      it "renders the related record" do
        expect(document.to_h[:included].map { it[:id] }).to eq([topic.user_id.to_s])
      end
    end
  end
end
