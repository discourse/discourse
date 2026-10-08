# frozen_string_literal: true

RSpec::Matchers.alias_matcher :accept, :be_accepts

RSpec.describe JsonApiKit::Declarations::Anchor::Computed do
  subject(:anchor) do
    described_class.new(:mine) { |topics, guardian| topics.where(user: guardian.user) }
  end

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
  let(:anchoring) { JsonApiKit::Anchoring.for(:mine) }

  describe "#accepts?" do
    it { is_expected.to accept(anchoring) }
    it { is_expected.not_to accept(JsonApiKit::Anchoring.for(mine: 12)) }
  end

  describe "#locatable_in?" do
    it { is_expected.to be_locatable_in(order) }
  end

  describe "#locate" do
    subject(:located_row) do
      anchor.locate(anchoring, scope: Topic.all, order:, guardian: Guardian.new(newest.user))
    end

    it "returns the row the declaration calculates for the guardian" do
      expect(located_row.record).to eq(newest)
    end
  end
end
