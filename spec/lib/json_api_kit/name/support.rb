# frozen_string_literal: true

RSpec.shared_examples "a name" do |kind|
  describe "#kind" do
    it "returns #{kind.inspect}" do
      expect(name.kind).to eq(kind)
    end
  end

  describe "#convert" do
    it "returns the name with the converted value" do
      expect(name.convert(&:upcase)).to eq(name.with(value: name.value.upcase))
    end
  end

  describe "#to_s" do
    it "returns the value" do
      expect(name.to_s).to eq(name.value)
    end
  end
end
