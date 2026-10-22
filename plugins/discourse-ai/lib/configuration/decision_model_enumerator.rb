# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class DecisionModelEnumerator < ::EnumSiteSetting
      def self.valid_value?(val)
        true
      end

      def self.values
        DB.query_hash(<<~SQL).map(&:symbolize_keys)
          SELECT display_name AS name, id AS value
          FROM decision_models
          ORDER BY display_name
        SQL
      end
    end
  end
end
