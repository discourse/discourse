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

    class NotAMemberName < BadParameter
      attr_reader :raw, :member

      def initialize(raw, member, parameter: nil)
        @raw = raw
        @member = member
        super("Use #{member}, not #{raw}.", parameter:)
      end

      def title = "Invalid member name"

      private

      def arguments = [raw, member]
    end

    class BadValue < BadParameter
      def initialize(names, parameter: nil)
        @names = names
        super("This version cannot convert the value of #{names.join(", ")}.", parameter:)
      end

      def title = "Invalid value"

      private

      attr_reader :names

      def arguments = [names]
    end

    class << self
      def kit = new([CasingRule])

      def resource(version) = new([CasingRule, VersionRule.new(version)])
    end

    def initialize(rules)
      @rules = rules
      @declared_names = {}
      @member_names = {}
    end

    def declared_attributes(attributes)
      attributes.each_key { declared_name(it) }
      rules.reduce(attributes) { |result, rule| rule.declared_attributes(result) }
    rescue VersionChange::Converter::Failure => failure
      raise BadValue.new(failure.names.map { member_name(it) })
    end

    def declared_name(name)
      declared_names[name] ||= rules.reduce(name) { |result, rule| rule.declared_name(result) }
    rescue Correction => correction
      raise NotAMemberName.new(name, member_name(correction.name))
    end

    def member_name(name)
      member_names[name] ||= rules
        .reverse_each
        .reduce(name) { |result, rule| rule.member_name(result) }
    end

    def member_attributes(attributes)
      rules.reverse_each.reduce(attributes) { |result, rule| rule.member_attributes(result) }
    end

    private

    attr_reader :rules, :declared_names, :member_names
  end
end
