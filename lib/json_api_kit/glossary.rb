# frozen_string_literal: true

module JsonApiKit
  class Glossary
    class Correction < StandardError
      attr_reader :name

      def initialize(name)
        @name = name
        super("Use #{name}.")
      end
    end

    class NotAMemberName < BadRequest
      attr_reader :raw, :member

      def initialize(raw, member, parameter: nil)
        @raw = raw
        @member = member
        @parameter = parameter
        super("Use #{member}, not #{raw}.")
      end

      def title = "Invalid member name"

      def source = { parameter: @parameter }.compact

      def at(parameter) = self.class.new(raw, member, parameter:)
    end

    class << self
      def kit = new([CasingRule])

      def resource(version) = new([CasingRule, VersionRule.new(version)])
    end

    def initialize(rules)
      @rules = rules
    end

    def declared_name(name)
      rules.reduce(name) { |result, rule| rule.declared_name(result) }
    rescue Correction => correction
      raise NotAMemberName.new(name, member_name(correction.name))
    end

    def member_name(name)
      rules.reverse_each.reduce(name) { |member, rule| rule.member_name(member) }
    end

    private

    attr_reader :rules
  end
end
