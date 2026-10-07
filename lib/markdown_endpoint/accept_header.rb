# frozen_string_literal: true

module MarkdownEndpoint
  module AcceptHeader
    module_function

    def quality(header, type, subtype)
      return 0.0 if header.blank?

      header.split(",").filter_map { |entry| match(entry, type, subtype) }.max&.last || 0.0
    end

    def preferred?(header)
      markdown = quality(header, "text", "markdown")
      alternatives = [quality(header, "text", "html"), quality(header, "application", "json")]
      markdown.positive? && markdown > alternatives.max
    end

    def match(entry, type, subtype)
      media_type, *parameters = entry.strip.split(";")
      candidate_type, candidate_subtype = media_type.to_s.downcase.strip.split("/", 2)
      return if candidate_subtype.blank?

      specificity =
        if candidate_type == type && candidate_subtype == subtype
          2
        elsif candidate_type == type && candidate_subtype == "*"
          1
        elsif candidate_type == "*" && candidate_subtype == "*"
          0
        end
      return unless specificity

      quality = 1.0
      parameters.each do |parameter|
        name, value = parameter.strip.split("=", 2)
        quality = value.to_f.clamp(0.0, 1.0) if name&.casecmp?("q")
      end
      [specificity, quality]
    end
    private_class_method :match
  end
end
