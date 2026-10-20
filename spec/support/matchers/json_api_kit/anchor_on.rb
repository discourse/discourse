# frozen_string_literal: true

require_relative "matcher"

module JsonApiKitMatchers
  class AnchorOn < Matcher
    attr_reader :names

    def initialize(names)
      @names = names.map(&:to_s)
    end

    def satisfied?
      undeclared.empty? && unlocatable.empty?
    end

    def description
      "anchor on #{names.join(", ")}"
    end

    def failure_message
      if undeclared.any?
        return(
          "Expected #{resource} to anchor on #{undeclared.join(", ")}, " \
            "but it anchors on #{in_words(resource.anchor_names)}."
        )
      end
      "Expected #{resource} to anchor on #{unlocatable.join(", ")}, " \
        "but none of its sorts can locate a row by that name."
    end

    private

    def undeclared = @undeclared ||= names - resource.anchor_names

    def unlocatable
      @unlocatable ||=
        names.reject { resource.anchored_by?(anchor_name: it, ordering: ordering_for(it)) }
    end

    def ordering_for(name) = resource.sort_names.include?(name) ? { name => :asc } : {}
  end
end
