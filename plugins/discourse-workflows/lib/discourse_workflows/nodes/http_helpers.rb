# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpHelpers
      def normalize_headers(headers_config)
        Array(headers_config).each_with_object({}) do |h, headers|
          headers[h["key"]] = h["value"] if h["key"].present?
        end
      end
    end
  end
end
