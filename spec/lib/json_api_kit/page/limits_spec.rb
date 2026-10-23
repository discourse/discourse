# frozen_string_literal: true

RSpec.describe JsonApiKit::Page::Limits do
  subject(:limits) { described_class.new(default: 20, max: 50) }

  describe ".new" do
    it "refuses a default the maximum forbids" do
      expect { described_class.new(default: 200, max: 50) }.to raise_error(
        described_class::OutOfRange,
      )
    end

    it "refuses a default below one" do
      expect { described_class.new(default: 0, max: 50) }.to raise_error(
        described_class::OutOfRange,
      )
    end

    it "refuses a maximum below one" do
      expect { described_class.new(max: 0) }.to raise_error(described_class::OutOfRange)
    end
  end

  describe "#size" do
    subject(:size) { limits.size(page_size) }

    let(:page_size) { 10 }

    it "returns the size a request asks for" do
      expect(size).to eq(10)
    end

    context "when a request asks for none" do
      let(:page_size) { nil }

      it "returns the resource's default size" do
        expect(size).to eq(20)
      end
    end

    context "when the resource declares a maximum below the kit's default size" do
      subject(:limits) { described_class.new(max: 10) }

      let(:page_size) { nil }

      it "returns the maximum" do
        expect(size).to eq(10)
      end
    end

    context "when the resource declares no limits of its own" do
      subject(:limits) { described_class.new }

      let(:page_size) { nil }

      it "returns the kit's default size" do
        expect(size).to eq(described_class::DEFAULT)
      end
    end
  end
end
