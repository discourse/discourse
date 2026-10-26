# frozen_string_literal: true

module WebsiteBrand
  # Helpers for raw CSS values, which can hold custom properties and nested
  # function calls.
  module CssValue
    MAX_VARIABLE_DEPTH = 6

    # Replaces each `var(--name, fallback)` with the variable's value, or its
    # fallback. Returns nil when a variable can't be resolved or the result
    # grows past `max_length`.
    def self.substitute_variables(value, variables, max_length:, depth: 0)
      value = value.to_s
      return value if !value.include?("var(")
      return if depth > MAX_VARIABLE_DEPTH

      result = +""
      position = 0
      while (start = value.index("var(", position))
        finish = closing_parenthesis(value, start + 3)
        return if finish.nil?

        name, fallback = split_arguments(value[(start + 4)...finish], limit: 2)
        replacement =
          substitute_variables(
            variables[name.to_s.strip.downcase] || fallback,
            variables,
            max_length:,
            depth: depth + 1,
          )
        return if replacement.blank?

        result << value[position...start] << replacement.strip
        return if result.length > max_length
        position = finish + 1
      end
      result << value[position..]
      result if result.length <= max_length
    end

    # The index of the parenthesis closing the one at `opening`.
    def self.closing_parenthesis(value, opening)
      depth = 0
      (opening...value.length).each do |index|
        case value[index]
        when "("
          depth += 1
        when ")"
          depth -= 1
          return index if depth.zero?
        end
      end
      nil
    end

    # Splits a list on the commas that aren't inside parentheses.
    def self.split_arguments(arguments, limit: nil)
      parts = [+""]
      depth = 0
      arguments.to_s.each_char do |char|
        depth += 1 if char == "("
        depth -= 1 if char == ")"
        if char == "," && depth.zero? && (limit.nil? || parts.size < limit)
          parts << +""
        else
          parts.last << char
        end
      end
      parts.map(&:strip)
    end
  end
end
