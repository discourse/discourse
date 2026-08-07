# frozen_string_literal: true

RSpec.describe JsonApiKit::Request do
  subject(:request) { described_class.new(params, guardian:) }

  let(:params) { {} }
  let(:guardian) { Guardian.new }

  describe ".new" do
    context "with a parameter the kit reads nothing from" do
      let(:params) { { sorts: { created_at: :asc } } }

      it "refuses it rather than reading a listing nobody asked for" do
        expect { request }.to raise_error(described_class::Unsupported, /sorts/)
      end
    end

    context "with a paging parameter the kit reads nothing from" do
      let(:params) { { page: { sise: 2 } } }

      it "refuses that too, a typo being a request for something else" do
        expect { request }.to raise_error(described_class::Unsupported, /sise/)
      end
    end
  end

  describe "#ordering" do
    subject(:ordering) { request.ordering }

    let(:params) { { sort: { created_at: :desc } } }

    it "is the ordering asked for" do
      expect(ordering).to eq(created_at: :desc)
    end

    context "when none was asked for" do
      let(:params) { {} }

      it "leaves the resource to say" do
        expect(ordering).to be_empty
      end
    end
  end

  describe "#filtering" do
    subject(:filtering) { request.filtering }

    let(:params) { { filter: { title: "a title" } } }

    it "is the filtering asked for" do
      expect(filtering).to eq(title: "a title")
    end

    context "when none was asked for" do
      let(:params) { {} }

      it "narrows nothing" do
        expect(filtering).to be_empty
      end
    end
  end

  describe "#page_size" do
    subject(:page_size) { request.page_size }

    let(:params) { { page: { size: 10 } } }

    it "is the size asked for" do
      expect(page_size).to eq(10)
    end

    context "when none was asked for" do
      let(:params) { {} }

      it "leaves the resource to say" do
        expect(page_size).to be_nil
      end
    end
  end

  describe "#after" do
    subject(:after) { request.after }

    let(:params) { { page: { after: JsonApiKit::Pagination::Cursor.new([12]).to_s } } }

    it "is the place the listing reads on from" do
      expect(after.values).to eq([12])
    end

    context "when none was asked for" do
      let(:params) { {} }

      it "reads the listing from its start" do
        expect(after).to be_nil
      end
    end

    context "with a cursor that is not one" do
      let(:params) { { page: { after: "not a cursor" } } }

      it "refuses it, the kit having minted every cursor it reads" do
        expect { after }.to raise_error(JsonApiKit::Pagination::Cursor::Invalid)
      end
    end
  end

  describe "#before" do
    subject(:before) { request.before }

    let(:params) { { page: { before: JsonApiKit::Pagination::Cursor.new([12]).to_s } } }

    it "is the place the listing reads back from" do
      expect(before.values).to eq([12])
    end
  end

  describe "#guardian" do
    subject(:asking) { request.guardian }

    it "is who is asking, which is what a resource's scope answers for" do
      expect(asking).to be(guardian)
    end
  end
end
