# frozen_string_literal: true

# TODO(@keegan): Remove after removing SiteSetting.summarization_strategy

require "enum_site_setting"

class SummarizationStrategy < EnumSiteSetting
  def self.valid_value?(val)
    true
  end

  def self.values
    @values ||=
      Summarization::Base.available_strategies.map do |strategy|
        { name: strategy.display_name, value: strategy.model }
      end
  end
end
