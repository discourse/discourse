# frozen_string_literal: true

module DiscourseAutomation
  class TemplateSerializer < ApplicationSerializer
    attributes :name, :component, :extra, :accepts_placeholders, :default_value

    def default_value
      if scope[:targetable].scriptable?
        scope[:targetable]&.forced_triggerable&.dig(:state, name)
      end
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
  end
end
