# frozen_string_literal: true

RSpec.describe JsonApiKit::DefaultSorts do
  subject(:defaults) { described_class.new(changes) }

  let(:changes) do
    [
      Class
        .new(JsonApiKit::VersionChange) do
          resource(:topics) { changed_default_sort from: { created_at: :desc } }
        end
        .new(__FILE__),
    ]
  end
  let(:resource) { resource_class.new(guardian:, edition:) }
  let(:guardian) { Guardian.new }
  let(:edition) { JsonApiKit::Edition.new(changes) }
  let(:resource_class) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      sort :created_at
      default_sort created_at: :asc
    end
  end

  describe "#for" do
    subject(:ordering) { defaults.for(resource) }

    it "returns the ordering from the resource's history" do
      expect(ordering).to eq("created_at" => :desc)
    end

    it "reuses the resolved ordering for the resource" do
      expect(defaults.for(resource)).to equal(ordering)
    end

    context "when another instance uses the same resource class" do
      let(:other_resource) { resource_class.new(guardian:, edition:) }

      before { ordering }

      it "reuses the resolved ordering" do
        expect(defaults.for(other_resource)).to equal(ordering)
      end
    end

    context "when another request uses the current edition" do
      let(:current_edition) { JsonApiKit::Edition.current }
      let(:current_resource) { resource_class.new(guardian:, edition: current_edition) }

      before { edition.default_sorts.for(resource) }

      it "resolves that edition's default" do
        expect(current_edition.default_sorts.for(current_resource)).to eq("created_at" => :asc)
      end
    end

    context "when two resource classes share a type" do
      let(:changes) { [] }
      let(:other_resource) do
        Class.new(resource_class) { default_sort created_at: :desc }.new(guardian:, edition:)
      end

      before { ordering }

      it "resolves each resource's own default" do
        expect(defaults.for(other_resource)).to eq("created_at" => :desc)
      end
    end
  end
end
