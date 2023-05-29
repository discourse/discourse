# frozen_string_literal: true

module Summarization
  class Base
    def self.available_strategies
      DiscoursePluginRegistry.summarization_strategies
    end

    def self.find_strategy(strategy_name)
      available_strategies.detect { |s| s.name == strategy_name }
    end

    def self.selected_strategy
      return if SiteSetting.summarization_strategy.blank?

      find_strategy(SiteSetting.summarization_strategy)
    end

    def self.name
      raise NotImplemented
    end
  end

  def correctly_configured?
    raise NotImplemented
  end

  def configuration_hint
    raise NotImplemented
  end

  def summarize(content)
    raise NotImplemented
  end
end
