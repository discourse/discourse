# frozen_string_literal: true

module Summarization
  class Base
    def self.available_strategies
      DiscoursePluginRegistry.summarization_strategies
    end

    def self.find_strategy(strategy_model)
      available_strategies.detect { |s| s.model == strategy_model }
    end

    def self.selected_strategy
      return if SiteSetting.summarization_strategy.blank?

      find_strategy(SiteSetting.summarization_strategy)
    end

    def initialize(model)
      @model = model
    end

    attr_reader :model

    def can_request_summaries?(user)
      user_group_ids = user.group_ids

      SiteSetting.custom_summarization_allowed_groups_map.any? do |group_id|
        user_group_ids.include?(group_id)
      end
    end

    def correctly_configured?
      raise NotImplemented
    end

    def display_name
      raise NotImplemented
    end

    def configuration_hint
      raise NotImplemented
    end

    def summarize(content)
      raise NotImplemented
    end
  end
end
