# frozen_string_literal: true

module SiteSettings
end

module SiteSettings::GroupRefs
  class SchemaError < StandardError
  end

  # The `everyone` pseudogroup is being retired, so it is deliberately absent from
  # the vocabulary: a rule or default may not name it. Its id still resolves,
  # because stored values and existing rules continue to contain it.
  RETIRED_NAMES = %i[everyone].freeze

  NAMES = Group::AUTO_GROUPS.except(*RETIRED_NAMES).freeze

  def self.resolve(ref, context:)
    return ref if ref.is_a?(Integer)

    token = ref.to_s if ref.is_a?(String) || ref.is_a?(Symbol)
    stripped = token&.strip

    return Integer(stripped, 10) if stripped&.match?(/\A[+-]?\d+\z/)

    if stripped.present? && stripped == token
      group_id = NAMES[stripped.to_sym]
      return group_id if group_id && stripped == stripped.downcase
    end

    suggestion =
      if stripped.present?
        DidYouMean::SpellChecker.new(dictionary: NAMES.keys.map(&:to_s)).correct(stripped).first
      end
    message = "#{context}: invalid automatic group reference #{ref.inspect}"
    message += "; did you mean #{suggestion.inspect}?" if suggestion
    raise SchemaError, message
  end

  def self.resolve_ids(value, context:)
    refs =
      case value
      when nil
        []
      when String
        value.split("|", -1)
      when Array
        value
      when Integer
        [value]
      else
        raise SchemaError, "#{context}: invalid group reference list #{value.inspect}"
      end

    refs
      .reject { |ref| ref.nil? || (ref.is_a?(String) && ref.strip.empty?) }
      .map { |ref| resolve(ref.is_a?(String) ? ref.strip : ref, context: context) }
      .uniq
  end

  def self.resolve_list(value, context:)
    resolve_ids(value, context: context).join("|")
  end
end
