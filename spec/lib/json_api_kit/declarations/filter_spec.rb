# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Filter do
  subject(:filter) { described_class.new(:title) { |scope, value| scope.where(title: value) } }

  fab!(:matching_topic) { Fabricate(:topic, title: "The rows a filter keeps") }
  fab!(:dropped_topic) { Fabricate(:topic, title: "The rows it leaves behind") }

  let(:scope) { Topic.all }

  describe "#name" do
    subject(:name) { filter.name }

    it "returns the name a request filters by" do
      expect(name).to eq("title")
    end
  end

  describe "#default" do
    it "has no default unless one is declared" do
      expect(filter.default?).to be(false)
    end

    context "with a declared default" do
      subject!(:filter) { described_class.new(:tags, default: declared) }

      let(:declared) { ["bug"] }

      it "keeps a frozen copy, so no request can change it for the next one" do
        declared << "feature"

        expect([filter.default?, filter.default, filter.default.frozen?]).to eq(
          [true, ["bug"], true],
        )
      end
    end

    context "with nil as the declared default" do
      subject(:filter) { described_class.new(:category, default: nil) }

      it "still counts as declaring one" do
        expect([filter.default?, filter.default]).to eq([true, nil])
      end
    end
  end

  describe "#apply" do
    subject(:kept_ids) { filter.apply(scope, matching_topic.title).map(&:id) }

    let(:context) do
      described_class::Context.new(
        guardian: Guardian.new,
        edition: JsonApiKit::Edition.current,
        filtering: {
          "alias" => matching_topic.title,
        },
      )
    end

    it "keeps the rows its declared condition allows" do
      expect(kept_ids).to contain_exactly(matching_topic.id)
    end

    context "when the condition also takes the request context" do
      subject(:filter) do
        described_class.new(:title) do |scope, _value, context|
          scope.where(title: context.filtering.fetch("alias"))
        end
      end

      it "hands the context to the condition" do
        expect(filter.apply(scope, "ignored", context).map(&:id)).to contain_exactly(
          matching_topic.id,
        )
      end
    end

    context "when a two-argument lambda condition is applied with a context" do
      subject(:filter) do
        described_class.new(:title, &->(scope, value) { scope.where(title: value) })
      end

      it "calls the condition with the scope and the value only" do
        expect(filter.apply(scope, matching_topic.title, context).map(&:id)).to contain_exactly(
          matching_topic.id,
        )
      end
    end

    context "when the filter declares no condition of its own" do
      subject(:filter) { described_class.new(:title) }

      let(:equality) { instance_spy(described_class::Equality) }

      before do
        allow(described_class::Equality).to receive(:new).with("title").and_return(equality)
      end

      it "compares the column of its own name to the value" do
        filter.apply(scope, matching_topic.title)

        expect(equality).to have_received(:call).with(scope, matching_topic.title)
      end
    end
  end
end
