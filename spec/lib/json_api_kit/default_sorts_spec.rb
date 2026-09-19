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
  let(:resource) do
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

    context "when two resource classes share a type" do
      let(:changes) { [] }
      let(:other_resource) { Class.new(resource) { default_sort created_at: :desc } }

      before { ordering }

      it "resolves each resource's own default" do
        expect(defaults.for(other_resource)).to eq("created_at" => :desc)
      end
    end
  end
end
