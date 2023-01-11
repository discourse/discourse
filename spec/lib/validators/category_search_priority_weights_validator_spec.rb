# frozen_string_literal: true

RSpec.describe CategorySearchPriorityWeightsValidator do
  it "should validate the results correctly" do
    [1, 1.1].each do |value|
      expect do SiteSetting.category_search_priority_low_weight = value end.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    [1, "0.9"].each do |value|
      expect do SiteSetting.category_search_priority_high_weight = value end.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end
end
