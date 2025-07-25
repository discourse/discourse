# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class PersonaEnumerator < ::EnumSiteSetting
      def self.valid_value?(val)
        true
      end

      def self.values
        AiPersona
          .all_personas(enabled_only: false)
          .map { |persona| { name: persona.name, value: persona.id } }
      end
    end
  end
end
