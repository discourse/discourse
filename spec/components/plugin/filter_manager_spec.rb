require 'spec_helper'
require_dependency 'plugin/filter_manager'

describe Plugin::FilterManager do
  let(:instance){ Plugin::FilterManager.new }

  it "calls registered filters correctly" do
    instance.register(:added_numbers) do |context,result|
      context + result + 1
    end

    instance.register(:added_numbers) do |context,result|
      context + result + 2
    end

    instance.apply(:added_numbers, 1, 0).should == 5
  end

  it "should raise an exception if wrong arity is passed in" do
    lambda do
      instance.register(:test) do
      end
    end.should raise_exception
  end

  it "should return the original if no filters exist" do
    instance.apply(:foo, nil, 42).should == 42
  end

  it "should raise an exception if no block is passed in" do
    lambda do
      instance.register(:test)
    end.should raise_exception
  end
end
