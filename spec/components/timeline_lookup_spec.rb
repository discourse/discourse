require 'rails_helper'
require_dependency 'timeline_lookup'

describe TimelineLookup do
  it "returns an empty array for empty input" do
    expect(TimelineLookup.build([])).to eq([])
  end

  it "returns the lookup for a series of posts" do
    result = TimelineLookup.build([[111, 1, 10], [222, 2, 9], [333, 3, 8]])
    expect(result).to eq([[1, 10], [2, 9], [3, 8]])
  end

  it "omits duplicate dates" do
    result = TimelineLookup.build([[111, 1, 10], [222, 2, 10], [333, 3, 8]])
    expect(result).to eq([[1, 10], [3, 8]])
  end

  it "respects holes in the post numbers" do
    result = TimelineLookup.build([[111, 1, 10], [222, 12, 10], [333, 30, 8]])
    expect(result).to eq([[1, 10], [3, 8]])
  end

  it "respects a `max_values` setting" do
    input = (1..100).map {|i| [1000+i, i, 100-i] }

    result = TimelineLookup.build(input, 5)
    expect(result.size).to eq(5)
    expect(result).to eq([[1, 99], [21, 79], [41, 59], [61, 39], [81, 19]])
  end

  it "respects an uneven `max_values` setting" do
    input = (1..100).map {|i| [1000+i, i, 100-i] }

    result = TimelineLookup.build(input, 3)
    expect(result.size).to eq(3)
    expect(result).to eq([[1, 99], [35, 65], [69, 31]])
  end

end
