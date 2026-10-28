# frozen_string_literal: true

RSpec.describe JsonApiKit::Resource do
  subject(:resource) { resource_class.new(guardian:, edition:) }

  let(:guardian) { Guardian.new }

  let(:edition) { JsonApiKit::Edition.new(changes) }
  let(:changes) { [removal_class.new(__FILE__)] }
  let(:removal_class) do
    Class.new(JsonApiKit::VersionChange) { resource(:topics) { removed_filter :closed } }
  end
  let(:resource_class) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      filter :title
      sort :created_at
      default_sort created_at: :desc
    end
  end
  let(:filter_name) do
    edition
      .glossary
      .declared_name(JsonApiKit::Name::Filter.new(value: "closed", type: "topics"))
      .value
  end

  describe "#apply_filters" do
    subject(:kept_ids) { resource.apply_filters(Topic.all, filtering).map(&:id) }

    fab!(:kept_topic) { Fabricate(:topic, title: "The rows a filter keeps", closed: false) }
    fab!(:dropped_topic) { Fabricate(:topic, title: "The rows it leaves behind", closed: true) }

    let(:changes) { [] }
    let(:filtering) { { "title" => kept_topic.title } }

    it "narrows the listing with the declared filter" do
      expect(kept_ids).to contain_exactly(kept_topic.id)
    end

    context "when a filter is declared before the next request" do
      subject(:kept_ids) { next_resource.apply_filters(Topic.all, filtering).map(&:id) }

      let(:next_resource) { resource_class.new(guardian:, edition:) }
      let(:filtering) { { "closed" => false } }

      before do
        resource.apply_filters(Topic.all)
        resource_class.filter(:closed)
      end

      it "uses the new declaration in the next resource instance" do
        expect(kept_ids).to contain_exactly(kept_topic.id)
      end
    end
  end

  describe "#filter_names" do
    subject(:names) { resource.filter_names }

    it "combines current declarations with the retained binding" do
      expect(names).to contain_exactly("title", filter_name)
    end
  end

  describe "#filters" do
    it "retains the collection for the resource instance" do
      expect(resource.filters).to equal(resource.filters)
    end

    context "when another request uses the current edition" do
      let(:current_resource) { resource_class.new(guardian:, edition: JsonApiKit::Edition.current) }

      before { resource.filter_names }

      it "uses only current declarations" do
        expect(current_resource.filter_names).to eq(["title"])
      end

      it "preserves the class declarations" do
        expect(resource_class.filter_names).to eq(["title"])
      end
    end

    context "when two resource classes share a type" do
      let(:other_resource) do
        Class.new(resource_class) { filter :archived }.new(guardian:, edition:)
      end

      before { resource.filter_names }

      it "uses each resource's own declarations" do
        expect(other_resource.filter_names).to contain_exactly("title", "archived", filter_name)
      end
    end
  end

  describe "#default_ordering" do
    subject(:ordering) { resource.default_ordering }

    it "preserves the resource's default sort" do
      expect(ordering).to eq("created_at" => :desc)
    end
  end

  describe "#record_for" do
    subject(:record) { resource.record_for(id) }

    fab!(:topic) { Fabricate(:topic, closed: false) }

    let(:id) { topic.id }
    let(:resource_class) { Class.new(super()) { scope { Topic.where(closed: false) } } }

    it "returns the model record" do
      expect(record).to eq(topic)
    end

    context "when the record is outside the resource scope" do
      fab!(:closed_topic) { Fabricate(:topic, closed: true) }

      let(:id) { closed_topic.id }

      it "refuses the lookup" do
        expect { record }.to raise_error(JsonApiKit::NotFound)
      end
    end

    context "when the record does not exist" do
      let(:id) { 0 }

      it "refuses the lookup" do
        expect { record }.to raise_error(JsonApiKit::NotFound)
      end
    end
  end

  describe "#related_scope" do
    subject(:scope) { resource.related_scope(:posts, owner_id:) }

    fab!(:topic) { Fabricate(:topic, closed: false) }
    fab!(:post) { Fabricate(:post, topic:) }
    fab!(:unrelated_post, :post)

    let(:changes) { [] }
    let(:owner_id) { topic.id }
    let(:resource_class) { Class.new(super()) { scope { Topic.where(closed: false) } } }

    it "restricts the association to the owner" do
      expect(scope).to contain_exactly(post)
    end

    context "when the owner is outside the resource scope" do
      fab!(:closed_topic) { Fabricate(:topic, closed: true) }

      let(:owner_id) { closed_topic.id }

      it "refuses the lookup" do
        expect { scope }.to raise_error(JsonApiKit::NotFound)
      end
    end
  end
end
