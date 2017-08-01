require 'rails_helper'
require_dependency 'plugin/filter_manager'

describe Plugin::FilterManager do
  let(:instance) { Plugin::FilterManager.new }

  it "calls registered filters correctly" do
    instance.register(:added_numbers) do |context, result|
      context + result + 1
    end

    instance.register(:added_numbers) do |context, result|
      context + result + 2
    end

    expect(instance.apply(:added_numbers, 1, 0)).to eq(5)
  end

  it "should raise an exception if wrong arity is passed in" do
    expect do
      instance.register(:test) do
      end
    end.to raise_error(ArgumentError)
  end

  it "should return the original if no filters exist" do
    expect(instance.apply(:foo, nil, 42)).to eq(42)
  end

  it "should raise an exception if no block is passed in" do
    expect do
      instance.register(:test)
    end.to raise_error(ArgumentError)
  end
end
