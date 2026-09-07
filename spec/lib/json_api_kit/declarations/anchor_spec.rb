# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Anchor do
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
  let(:guardian) { Guardian.new }
  let(:located_row) { anchor.locate(Topic.all, value:, order:, guardian:) }
  let(:value) { Time.utc(2026, 8, 3) }

  describe "#name" do
    it "returns the name a request anchors by" do
      expect(anchor.name).to eq("created_at")
    end
  end

  describe "#locatable_in?" do
    context "when the anchor is the leading key" do
      it { is_expected.to be_locatable_in(order) }
    end

    context "when the anchor is the primary key" do
      subject(:anchor) { described_class.new(:id) }

      it { is_expected.to be_locatable_in(order) }
    end

    context "when the resource declares how to calculate the anchor" do
      subject(:anchor) do
        described_class.new(:mine) { |topics, guardian| topics.where(user: guardian.user) }
      end

      it { is_expected.to be_locatable_in(order) }
    end

    context "when the anchor is not in the order" do
      subject(:anchor) { described_class.new(:title) }

      it { is_expected.not_to be_locatable_in(order) }
    end
  end

  describe "#locate" do
    context "when the anchor is the leading key" do
      it "returns the row the listing enters at that value" do
        expect(located_row.record).to eq(newest)
      end
    end

    context "when the anchor is the primary key" do
      subject(:anchor) { described_class.new(:id) }

      let(:value) { newest.id }

      it "returns the row with that id" do
        expect(located_row.record).to eq(newest)
      end

      context "when no row holds that id" do
        let(:value) { -1 }

        it "refuses the request" do
          expect { located_row }.to raise_error(described_class::NoRow)
        end
      end
    end

    context "when the anchor is not in the order" do
      subject(:anchor) { described_class.new(:title) }

      let(:value) { newest.title }

      it "refuses the request" do
        expect { located_row }.to raise_error(ArgumentError, /title/)
      end
    end

    context "when the resource declares how to calculate the anchor" do
      subject(:anchor) do
        described_class.new(:mine) { |topics, guardian| topics.where(user: guardian.user) }
      end

      let(:guardian) { Guardian.new(newest.user) }
      let(:value) { nil }

      it "returns the row that declaration calculates for the guardian" do
        expect(located_row.record).to eq(newest)
      end
    end
  end

  describe described_class::NoRow do
    subject(:error) { described_class.new("created_at", value) }

    describe "#title" do
      it "returns the title of the error" do
        expect(error.title).to eq("No row for the anchor")
      end
    end

    describe "#source" do
      it "points at that anchor" do
        expect(error.source).to eq(parameter: "page[anchor][created_at]")
      end
    end
  end
end
