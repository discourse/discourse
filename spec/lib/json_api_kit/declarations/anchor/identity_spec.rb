# frozen_string_literal: true

RSpec::Matchers.alias_matcher :accept, :be_accepts

RSpec.describe JsonApiKit::Declarations::Anchor::Identity do
  subject(:anchor) { described_class.new(:id) }

  fab!(:oldest) { Fabricate(:topic, created_at: Time.utc(2026, 8, 1)) }
  fab!(:newest) { Fabricate(:topic, created_at: Time.utc(2026, 8, 3)) }
  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      sort :created_at
      default_sort created_at: :asc
    end
  end
  let(:order) { resource.order("created_at" => :asc) }
  let(:anchoring) { JsonApiKit::Anchoring.for(id: newest.id) }

  describe "#accepts?" do
    it { is_expected.to accept(anchoring) }
    it { is_expected.not_to accept(JsonApiKit::Anchoring.for(id: [newest.id])) }
    it { is_expected.not_to accept(JsonApiKit::Anchoring.for(:id)) }
  end

  describe "#locatable_in?" do
    it { is_expected.to be_locatable_in(order) }
  end

  describe "#locate" do
    subject(:located_row) do
      anchor.locate(anchoring, scope: Topic.all, order:, guardian: Guardian.new)
    end

    it "returns the row with that id" do
      expect(located_row.record).to eq(newest)
    end

    context "when no row holds that id" do
      let(:anchoring) { JsonApiKit::Anchoring.for(id: -1) }

      it "raises no row for the anchor" do
        expect { located_row }.to raise_error(JsonApiKit::Declarations::Anchor::NoRow)
      end
    end
  end
end
