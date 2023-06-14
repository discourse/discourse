# frozen_string_literal: true

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
