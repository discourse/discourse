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

    context "when a filter reads the guardian from the context" do
      let(:resource_class) do
        Class.new(super()) do
          filter(:mine) { |scope, _value, context| scope.where(user_id: context.guardian.user&.id) }
        end
      end
      let(:filtering) { { "mine" => "true" } }
      let(:guardian) { kept_topic.user.guardian }

      it "narrows the listing with the resource's guardian" do
        expect(kept_ids).to contain_exactly(kept_topic.id)
      end

      context "when the guardian is anonymous" do
        let(:guardian) { Guardian.new }

        it "keeps no rows" do
          expect(kept_ids).to be_empty
        end
      end
    end

    context "when a filter reads another filter's value from the context" do
      let(:resource_class) do
        Class.new(super()) do
          filter(:requires_title) do |scope, _value, context|
            context.filtering.key?("title") ? scope : scope.none
          end
        end
      end
      let(:filtering) { { "title" => kept_topic.title, "requires_title" => "true" } }

      it "sees every value the request filters by" do
        expect(kept_ids).to contain_exactly(kept_topic.id)
      end
    end

    context "when a filter declares a default and the request leaves it out" do
      let(:resource_class) { Class.new(super()) { filter :closed, default: false } }
      let(:filtering) { {} }

      it "narrows the listing with the default" do
        expect(kept_ids).to contain_exactly(kept_topic.id)
      end

      context "when the request sends a value" do
        let(:filtering) { { "closed" => true } }

        it "narrows the listing with that value instead" do
          expect(kept_ids).to contain_exactly(dropped_topic.id)
        end
      end

      context "when another filter reads it from the context" do
        let(:resource_class) do
          Class.new(super()) do
            filter(:open_only) do |scope, _value, context|
              context.filtering["closed"] == false ? scope : scope.none
            end
          end
        end
        let(:filtering) { { "open_only" => "true" } }

        it "sees the default as the request's value" do
          expect(kept_ids).to contain_exactly(kept_topic.id)
        end
      end
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

  describe "#apply_input_scope" do
    subject(:kept_ids) { resource.apply_input_scope(rows, filtering).map(&:id) }

    fab!(:open_topic) { Fabricate(:topic, closed: false) }
    fab!(:closed_topic) { Fabricate(:topic, closed: true) }
    fab!(:unlisted_topic, :topic)

    let(:changes) { [] }
    let(:rows) { Topic.where(id: [open_topic.id, closed_topic.id]) }
    let(:filtering) { {} }

    it "returns the rows when the resource declares no input scope" do
      expect(resource.apply_input_scope(rows, filtering)).to be(rows)
    end

    context "when the resource declares an input scope" do
      let(:resource_class) do
        Class.new(super()) do
          scope_filter :closed_too, default: false
          input_scope do |topics, _guardian, closed_too:|
            closed_too == "true" ? topics : topics.where(closed: false)
          end
        end
      end

      it "hands it the default when the request leaves the input out" do
        expect(kept_ids).to contain_exactly(open_topic.id)
      end

      context "when the request sends the input" do
        let(:filtering) { { "closed_too" => "true" } }

        it "hands it the value instead" do
          expect(kept_ids).to contain_exactly(open_topic.id, closed_topic.id)
        end
      end
    end

    context "when the input scope reads the guardian" do
      let(:resource_class) do
        Class.new(super()) do
          input_scope { |topics, guardian| topics.where(user_id: guardian.user&.id) }
        end
      end
      let(:guardian) { open_topic.user.guardian }

      it "hands it the resource's guardian" do
        expect(kept_ids).to contain_exactly(open_topic.id)
      end
    end

    context "when the input scope returns rows it did not receive" do
      # The block constrains the same column as the visible rows, which `merge` would replace.
      let(:resource_class) do
        Class.new(super()) do
          input_scope { |_topics, _guardian| Topic.where(id: Topic.select(:id)) }
        end
      end

      it "keeps only the rows it received, so it cannot widen the visible ones" do
        expect(kept_ids).to contain_exactly(open_topic.id, closed_topic.id)
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
end
