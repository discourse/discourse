# frozen_string_literal: true

RSpec.describe TimelineLookup do
  it "returns an empty array for empty input" do
    expect(TimelineLookup.build([])).to eq([])
  end

  it "returns an empty array for if input is an array if post ids" do
    expect(TimelineLookup.build([1, 2, 3])).to eq([])
  end

  it "returns the lookup for a series of posts" do
    result = TimelineLookup.build([[111, 10], [222, 9], [333, 8]])
    expect(result).to eq([[1, 10], [2, 9], [3, 8]])
  end

  it "omits duplicate dates" do
    result = TimelineLookup.build([[111, 10], [222, 10], [333, 8]])
    expect(result).to eq([[1, 10], [3, 8]])
  end

  it "respects a `max_values` setting" do
    input = (1..100).map { |i| [1000 + i, 100 - i] }

    result = TimelineLookup.build(input, 5)
    # even if max_value is 5 we might get 6 (5 + 1)
    # to ensure the last tuple is captured
    expect(result).to eq(
      [[1, 99], [21, 79], [41, 59], [61, 39], [81, 19], [input.size, input.last[1]]],
    )
  end

  it "respects an uneven `max_values` setting" do
    input = (1..100).map { |i| [1000 + i, 100 - i] }

    result = TimelineLookup.build(input, 3)
    # even if max_value is 3 we might get 4 (3 + 1)
    # to ensure the last tuple is captured
    expect(result.size).to eq(4)
    expect(result).to eq([[1, 99], [35, 65], [69, 31], [input.size, input.last[1]]])
  end
end
