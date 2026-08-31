# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Anchors do
  subject(:anchors) { described_class.new(declarations, guardian:) }

  let(:anchor_class) { JsonApiKit::Declarations::Anchor }
  let(:created_at_anchor) { anchor_class.new(:created_at) }
  let(:declarations) { [anchor_class.new(:id), created_at_anchor] }
  let(:guardian) { Guardian.new }
  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      sort :created_at
      default_sort created_at: :asc
    end
  end
  let(:order) { resource.order("created_at" => :asc) }

  describe "#fetch" do
    subject(:anchor_declaration) { anchors.fetch("created_at") }

    it "returns that anchor" do
      expect(anchor_declaration).to be(created_at_anchor)
    end

    context "when the resource declares no anchor by that name" do
      subject(:anchor_declaration) { anchors.fetch("secrets") }

      it "refuses the request" do
        expect { anchor_declaration }.to raise_error(KeyError)
      end
    end
  end

  describe "#locate" do
    subject(:located_row) { anchors.locate(anchoring, scope:, order:) }

    let(:scope) { Topic.all }
    let(:anchoring) { JsonApiKit::Anchoring.for(created_at: Time.utc(2026, 8, 3)) }
    let(:row) { instance_double(JsonApiKit::Pagination::Row) }

    before { allow(created_at_anchor).to receive(:locate).and_return(row) }

    it "asks the matching anchor to locate the row" do
      located_row

      expect(created_at_anchor).to have_received(:locate).with(
        scope,
        value: Time.utc(2026, 8, 3),
        order:,
        guardian:,
      )
    end

    it "returns the row that anchor locates" do
      expect(located_row).to be(row)
    end
  end
end
