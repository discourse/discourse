# frozen_string_literal: true

RSpec.describe JsonApiKit::Adapters::ActiveRecord do
  subject(:adapter) { described_class.new(resource) }

  fab!(:kept_topic) { Fabricate(:topic, title: "The rows a filter keeps") }
  fab!(:also_kept) { Fabricate(:topic, title: "More rows it keeps as well") }
  fab!(:dropped_topic) { Fabricate(:topic, title: "The rows it leaves behind") }

  let(:resource) do
    Class
      .new(JsonApiKit::Resource) do
        model Topic
        type :topics
      end
      .new(guardian:)
  end
  let(:guardian) { Guardian.new }
  let(:params) { {} }
  let(:request) do
    JsonApiKit::Request::Collection.new(params, guardian:, edition: JsonApiKit::Edition.current)
  end

  describe "#filter" do
    subject(:kept_ids) { adapter.filter(Topic.all, "title", value).map(&:id) }

    let(:value) { kept_topic.title }

    it "keeps the rows whose column holds the value" do
      expect(kept_ids).to contain_exactly(kept_topic.id)
    end

    context "when the value is an array" do
      let(:value) { [kept_topic.title, also_kept.title] }

      it "keeps the rows whose column holds one of them" do
        expect(kept_ids).to contain_exactly(kept_topic.id, also_kept.id)
      end
    end
  end

  describe "#requested_page" do
    subject(:page) { adapter.requested_page(request) }

    it "returns the page at the start of the listing" do
      expect(page).to be_a(JsonApiKit::Adapters::ActiveRecord::Page::Requested::First)
    end

    context "when the page holds an after cursor" do
      let(:params) do
        { page: { after: JsonApiKit::Adapters::ActiveRecord::Pagination::Cursor.new([12]).to_s } }
      end

      it "returns the page that carries on from it" do
        expect(page).to be_a(JsonApiKit::Adapters::ActiveRecord::Page::Requested::After)
      end
    end

    context "when the page holds a before cursor" do
      let(:params) do
        { page: { before: JsonApiKit::Adapters::ActiveRecord::Pagination::Cursor.new([12]).to_s } }
      end

      it "returns the page before it" do
        expect(page).to be_a(JsonApiKit::Adapters::ActiveRecord::Page::Requested::Before)
      end
    end

    context "when the cursor cannot be read" do
      let(:params) { { page: { after: "not a cursor" } } }

      it "refuses the request" do
        expect { page }.to raise_error(ArgumentError)
      end
    end

    context "when there is an anchor parameter" do
      let(:params) { { page: { anchor: { id: 12 } } } }

      it "returns the page around it" do
        expect(page).to be_a(JsonApiKit::Adapters::ActiveRecord::Page::Requested::Around)
      end
    end
  end
end
