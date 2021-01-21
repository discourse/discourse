# frozen_string_literal: true

module DiscourseAutomation
  class FieldSerializer < ApplicationSerializer
    attributes :id, :component, :name, :metadata, :placeholders

    def placeholders
      field = scope[:scriptable].fields.detect do |s|
        s[:name].to_s == object.name && s[:component].to_s == object.component
      end

      if !field || field[:accepts_placeholders].blank?
        nil
      else
        scope[:scriptable].placeholders.map { |placeholder| "%%#{placeholder.upcase}%%" }
      end
    end
  end
end
