# frozen_string_literal: true

module DiscourseAutomation
  class FieldSerializer < ApplicationSerializer
    attributes :id, :component, :name, :metadata, :placeholders, :target, :extra

    def metadata
      object.metadata || {}
    end

    def target
      object.target || scope[:target_name]
    end

    def extra
      targetable_field[:extra]
    end

    def placeholders
      if !targetable_field || targetable_field[:accepts_placeholders].blank?
        nil
      else
        scope[:placeholders].map { |placeholder| "%%#{placeholder.upcase}%%" }
      end
    end

    def targetable_field
      @targetable_field ||= scope[:target].fields.detect do |s|
        s[:name].to_s == object.name && s[:component].to_s == object.component
      end
    end
  end
end
