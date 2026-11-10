# frozen_string_literal: true

RSpec.describe Plugin::FilterManager do
  let(:instance) { Plugin::FilterManager.new }

  it "calls registered filters correctly" do
    instance.register(:added_numbers) { |context, result| context + result + 1 }

    instance.register(:added_numbers) { |context, result| context + result + 2 }

    expect(instance.apply(:added_numbers, 1, 0)).to eq(5)
  end

  it "raises an exception for an invalid arity" do
    expect do instance.register(:test) {} end.to raise_error(ArgumentError)
  end

  it "returns the original value when no filters exist" do
    expect(instance.apply(:foo, nil, 42)).to eq(42)
  end

  it "raises an exception when no block is provided" do
    expect do instance.register(:test) end.to raise_error(ArgumentError)
  end
end
