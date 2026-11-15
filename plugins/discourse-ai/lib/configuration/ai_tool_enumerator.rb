# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class AiToolEnumerator < ::EnumSiteSetting
      def self.valid_value?(val)
        true
      end

      def self.values
        AiTool.order(:name).pluck(:name, :id).map { |name, id| { name:, value: id } }
      end
    end
  end
end
