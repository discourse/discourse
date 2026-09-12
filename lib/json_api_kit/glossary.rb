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
      rules
        .each_with_index
        .reduce(attributes) do |result, (rule, index)|
          rule.declared_attributes(result)
        rescue VersionChange::Converter::Failure => failure
          raise BadValue.new(member_names_before(failure.names, index))
        end
    end

    def declared_name(name)
      declared_names[name] ||= declare_name(name, rules)
    rescue Correction => correction
      raise NotAMemberName.new(name, member_name(correction.name))
    end

    def member_name(name)
      member_names[name] ||= rules
        .reverse_each
        .reduce(name) { |result, rule| rule.member_name(result) }
    end

    def member_type(type) = member_name(Name::Type.new(value: type)).value

    def member_attributes(attributes)
      rules.reverse_each.reduce(attributes) { |result, rule| rule.member_attributes(result) }
    end

    private

    attr_reader :rules, :declared_names, :member_names

    def member_names_before(names, rule_index)
      rules
        .take(rule_index)
        .reverse_each
        .reduce(names) { |result, rule| result.map { rule.member_name(it) } }
    end

    def declare_name(name, remaining_rules)
      remaining_rules.reduce(name) do |result, rule|
        rule.declared_name(result)
      rescue Correction => correction
        raise Correction.new(
                declare_name(
                  correction.name,
                  remaining_rules.drop(remaining_rules.index(rule) + 1),
                ),
              )
      end
    end
  end
end
