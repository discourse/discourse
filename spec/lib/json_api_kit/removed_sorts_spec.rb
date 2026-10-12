# frozen_string_literal: true

RSpec.describe JsonApiKit::RemovedSorts do
  subject(:removed_sorts) { described_class.new(changes) }

  let(:changes) { [removal] }
  let(:removal) { removal_class.new(__FILE__) }
  let(:removal_class) do
    Class.new(JsonApiKit::VersionChange) do
      resource(:topics) { removed_sort :created_at }
      resource(:groups) { removed_sort :name }
    end
  end
  let(:topic_sort) { removal_class.removed_sorts.first }

  describe "#for" do
    subject(:sorts) { removed_sorts.for(type).to_a }

    let(:type) { "topics" }

    it "returns the resource's retained sorts" do
      expect(sorts).to contain_exactly(topic_sort)
    end

    context "when the edition has no changes" do
      let(:changes) { [] }

      it "returns no retained sorts" do
        expect(sorts).to be_empty
      end
    end

    context "when the resource has no removed sorts" do
      let(:type) { "users" }

      it "returns no retained sorts" do
        expect(sorts).to be_empty
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

      it "finds the sorts under the resource's earlier type" do
        expect(sorts).to contain_exactly(topic_sort)
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

        it "returns only that resource's retained sorts" do
          expect(sorts).to contain_exactly(removal_class.removed_sorts.last)
        end
      end
    end
  end
end
