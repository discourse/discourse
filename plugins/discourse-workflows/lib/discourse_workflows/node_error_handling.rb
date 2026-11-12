# frozen_string_literal: true

module DiscourseWorkflows
  module NodeErrorHandling
    private

    # html is an optional full-message replacement, sanitized by NodeError. Keep a plain-text
    # message for logs, exports, and per-item or continued errors; escape dynamic HTML values.
    def raise_node_error!(message, description: nil, item_index: nil, line_number: nil, html: nil)
      suffix = +""
      suffix << " [line #{line_number}" if line_number
      suffix << (line_number ? ", for item #{item_index}" : " [item #{item_index}") if item_index
      suffix.presence&.<<("]")

      details = description.present? ? ": #{description}" : ""

      raise DiscourseWorkflows::NodeError.new(
              "#{message}#{suffix}#{details}",
              summary: "#{message}#{details}",
              html: html,
            )
    end
  end
end
