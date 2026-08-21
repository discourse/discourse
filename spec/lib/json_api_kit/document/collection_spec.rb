# frozen_string_literal: true

RSpec.describe JsonApiKit::Document::Collection do
  subject(:document) { described_class.new(listing, urls:) }

  fab!(:first_topic) do
    Fabricate(:topic, title: "Segments of a listing", created_at: Time.utc(2026, 8, 1))
  end
  fab!(:second_topic) do
    Fabricate(:topic, title: "Cursors and their values", created_at: Time.utc(2026, 8, 2))
  end

  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      sort :created_at
      default_sort created_at: :asc
      attribute :title
    end
  end
  let(:guardian) { Guardian.new }
  let(:urls) { JsonApiKit::Urls.new(base: "https://example.com/api", current:) }
  let(:current) { "https://example.com/api/topics" }
  let(:self_link) { { href: current, type: JsonApiKit::Pagination::Profile::MEDIA_TYPE } }
  let(:params) { {} }
  let(:listing) { resource.all(params, guardian:) }
  let(:primary_data) { document.to_h[:data] }
  let(:first_record) { listing.records.to_a.first }
  let(:second_record) { listing.records.to_a.last }

  describe "#to_h" do
    before { allow(JsonApiKit::Document::ResourceObject).to receive(:new).and_call_original }

    it "renders the records as data" do
      expect(primary_data.map { it[:id] }).to eq([first_topic.id.to_s, second_topic.id.to_s])
    end

    it "renders each record with no page meta" do
      document.to_h

      expect(JsonApiKit::Document::ResourceObject).to have_received(:new).with(
        first_record,
        urls:,
        meta: {
        },
      )
      expect(JsonApiKit::Document::ResourceObject).to have_received(:new).with(
        second_record,
        urls:,
        meta: {
        },
      )
    end

    context "when the request asks for the cursor of each row" do
      let(:params) { { page: { item_cursors: true } } }

      it "renders each record with its cursor" do
        document.to_h

        expect(JsonApiKit::Document::ResourceObject).to have_received(:new).with(
          first_record,
          urls:,
          meta: {
            page: {
              cursor: first_record.cursor.to_s,
            },
          },
        )
        expect(JsonApiKit::Document::ResourceObject).to have_received(:new).with(
          second_record,
          urls:,
          meta: {
            page: {
              cursor: second_record.cursor.to_s,
            },
          },
        )
      end
    end

    context "when the listing reads no row" do
      let(:listing) { resource.all({}, guardian:, scoped_to: Topic.where(id: -1)) }

      it "renders an empty document" do
        expect(document.to_h).to eq(
          data: [],
          included: [],
          links: {
            self: self_link,
            prev: nil,
            next: nil,
          },
        )
      end
    end

    context "when a page lies at each end of the listing" do
      fab!(:third_topic) do
        Fabricate(:topic, title: "Links to the pages at each end", created_at: Time.utc(2026, 8, 3))
      end

      let(:first_page) { resource.all({ page: { size: 1 } }, guardian:) }
      let(:listing) do
        resource.all({ page: { size: 1, after: first_page.records.first.cursor.to_s } }, guardian:)
      end
      let(:page_cursor) { listing.records.first.cursor }

      it "renders a link to the page at each end" do
        expect(document.to_h[:links]).to eq(
          self: self_link,
          prev: "https://example.com/api/topics?page%5Bbefore%5D=#{page_cursor}",
          next: "https://example.com/api/topics?page%5Bafter%5D=#{page_cursor}",
        )
      end
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
      let(:listing) { resource.all({ include: %w[user] }, guardian:) }

      it "renders every related record" do
        expect(document.to_h[:included].map { it[:id] }).to contain_exactly(
          first_topic.user_id.to_s,
          second_topic.user_id.to_s,
        )
      end
    end
  end
end
