# frozen_string_literal: true

module DiscourseAutomation
  class FieldSerializer < ApplicationSerializer
    attributes :id, :component, :name, :metadata, :placeholders

    def placeholders
      script_field = scope[:script_options].script_fields.detect do |s|
        s[:name].to_s == object.name && s[:component].to_s == object.component
      end

      if script_field && script_field[:placeholders].blank?
        nil
      else
        scope[:script_options].script_placeholders
      end
    end
  end
end
