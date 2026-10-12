# frozen_string_literal: true

RSpec.describe JsonApiKit::RemovedFilters do
  subject(:removed_filters) { described_class.new(changes) }

  let(:changes) { [removal] }
  let(:removal) { removal_class.new(__FILE__) }
  let(:removal_class) do
    Class.new(JsonApiKit::VersionChange) do
      resource(:topics) { removed_filter :closed }
      resource(:groups) { removed_filter :name }
    end
  end
  let(:topic_filter) { removal_class.removed_filters.first }

  describe "#for" do
    subject(:filters) { removed_filters.for(type).to_a }

    let(:type) { "topics" }

    it "returns the resource's retained filters" do
      expect(filters).to contain_exactly(topic_filter)
    end

    context "when the edition has no changes" do
      let(:changes) { [] }

      it "returns no retained filters" do
        expect(filters).to be_empty
      end
    end

    context "when the resource has no removed filters" do
      let(:type) { "users" }

      it "returns no retained filters" do
        expect(filters).to be_empty
      end
    end

    context "when the resource type changes after removal" do
      let(:type) { "threads" }
      let(:changes) do
        [
          removal,
          Class
            .new(JsonApiKit::VersionChange) { renamed_type from: :topics, to: :threads }
            .new(__FILE__),
        ]
      end

      it "finds the filters under the resource's earlier type" do
        expect(filters).to contain_exactly(topic_filter)
      end

      context "when another resource acquires the earlier type" do
        let(:type) { "topics" }
        let(:changes) do
          super() +
            [
              Class
                .new(JsonApiKit::VersionChange) { renamed_type from: :groups, to: :topics }
                .new(__FILE__),
            ]
        end

        it "returns only that resource's retained filters" do
          expect(filters).to contain_exactly(removal_class.removed_filters.last)
        end
      end
    end
  end
end
