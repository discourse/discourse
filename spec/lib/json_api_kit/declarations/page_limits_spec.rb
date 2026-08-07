# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::PageLimits do
  subject(:limits) { described_class.new(default: 20, max: 50) }

  describe "#size" do
    subject(:size) { limits.size(asked) }

    let(:asked) { 10 }

    it "is the size a request asks for" do
      expect(size).to eq(10)
    end

    context "when a request asks for none" do
      let(:asked) { nil }

      it "is the size the resource reads by default" do
        expect(size).to eq(20)
      end
    end

    context "when a request asks for more than the resource allows" do
      let(:asked) { 5_000 }

      it "refuses to read a page nobody bounded" do
        expect { size }.to raise_error(described_class::TooLarge, /50/)
      end
    end

    context "with a resource that declares no limits of its own" do
      subject(:limits) { described_class.new }

      let(:asked) { nil }

      it "reads a page of the size the kit reads by default" do
        expect(size).to eq(described_class::DEFAULT)
      end

      context "when a request asks for more than the kit allows" do
        let(:asked) { described_class::MAX + 1 }

        it "refuses that too" do
          expect { size }.to raise_error(described_class::TooLarge)
        end
      end
    end
  end
end
