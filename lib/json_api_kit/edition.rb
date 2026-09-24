# frozen_string_literal: true

module JsonApiKit
  class Edition
    class << self
      def for(version) = new(VersionChanges.core.after(version))

      def current = new([])
    end

    def initialize(changes)
      @changes = changes.dup.freeze
    end

    def glossary
      @glossary ||= Glossary.new([Glossary::CasingRule, Glossary::VersionRule.new(changes)])
    end

    def default_sorts = @default_sorts ||= DefaultSorts.new(changes)

    private

    attr_reader :changes
  end
end
