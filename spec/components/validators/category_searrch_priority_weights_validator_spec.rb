# frozen_string_literal: true

require 'rails_helper'
require 'validators/category_search_priority_weights_validator'

RSpec.describe CategorySearchPriorityWeightsValidator do
  it "should validate the results correctly" do
    expect do
      SiteSetting.category_search_priority_very_low_weight = 0.9
    end.to raise_error(Discourse::InvalidParameters)

    [1, 0].each do |value|
      expect do
        SiteSetting.category_search_priority_low_weight = value
      end.to raise_error(Discourse::InvalidParameters)
    end

    ['0.2', 10].each do |value|
      expect do
        SiteSetting.category_search_priority_high_weight = value
      end.to raise_error(Discourse::InvalidParameters)
    end

    expect do
      SiteSetting.category_search_priority_very_high_weight = 1.1
    end.to raise_error(Discourse::InvalidParameters)
  end
end
