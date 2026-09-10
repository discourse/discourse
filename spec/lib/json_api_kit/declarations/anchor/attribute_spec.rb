# frozen_string_literal: true

RSpec::Matchers.alias_matcher :accept, :be_accepts

RSpec.describe JsonApiKit::Declarations::Anchor::Attribute do
  subject(:anchor) { described_class.new(:created_at) }

  fab!(:oldest) { Fabricate(:topic, created_at: Time.utc(2026, 8, 1)) }
  fab!(:newest) { Fabricate(:topic, created_at: Time.utc(2026, 8, 3)) }
  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      sort :created_at
      sort :title
      default_sort created_at: :asc
    end
  end
  let(:order) { resource.order("created_at" => :asc) }
  let(:anchoring) { JsonApiKit::Anchoring.for(created_at: Time.utc(2026, 8, 3)) }

  describe "#accepts?" do
    it { is_expected.to accept(anchoring) }
    it { is_expected.not_to accept(JsonApiKit::Anchoring.for(created_at: [Time.utc(2026, 8, 3)])) }
    it { is_expected.not_to accept(JsonApiKit::Anchoring.for(:created_at)) }
  end

  describe "#locatable_in?" do
    it { is_expected.to be_locatable_in(order) }

    context "when the attribute is not the leading key of the order" do
      let(:order) { resource.order("title" => :asc) }

      it { is_expected.not_to be_locatable_in(order) }
    end
  end

  describe "#locate" do
    subject(:located_row) do
      anchor.locate(anchoring, scope: Topic.all, order:, guardian: Guardian.new)
    end

    it "returns the row the listing enters at that value" do
      expect(located_row.record).to eq(newest)
    end

    context "when the attribute is not the leading key of the order" do
      let(:order) { resource.order("title" => :asc) }

      it "raises with the anchor name" do
        expect { located_row }.to raise_error(ArgumentError, /created_at/)
      end
    end
  end
end
