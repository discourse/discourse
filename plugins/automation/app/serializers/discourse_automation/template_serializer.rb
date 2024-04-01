# frozen_string_literal: true

module DiscourseAutomation
  class TemplateSerializer < ApplicationSerializer
    attributes :name,
               :component,
               :extra,
               :accepts_placeholders,
               :accepted_contexts,
               :read_only,
               :default_value,
               :is_required

    def default_value
      scope[:automation].scriptable&.forced_triggerable&.dig(:state, name) || object[:default_value]
    end

    def read_only
      scope[:automation].scriptable&.forced_triggerable&.dig(:state, name).present?
    end

    def name
      object[:name]
    end

    def component
      object[:component]
    end

    def extra
      object[:extra]
    end

    def accepts_placeholders
      object[:accepts_placeholders]
    end

    def accepted_contexts
      object[:accepted_contexts]
    end

    def is_required
      object[:required]
    end
  end
end
