# frozen_string_literal: true

module JsonApiKit
  class Glossary
    class << self
      def kit = new([CasingRule])

      # TODO: add the versioning rule here (next PR)
      def resource = kit
    end

    def initialize(rules)
      @rules = rules
    end

    def declared_name(raw) = rules.reduce(raw) { |name, rule| rule.declared_name(name) }

    def member_name(name)
      rules.reverse_each.reduce(name) { |member, rule| rule.member_name(member) }
    end

    private

    attr_reader :rules
  end
end
