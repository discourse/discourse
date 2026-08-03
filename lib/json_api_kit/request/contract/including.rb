# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Including
        extend ActiveSupport::Concern

        included do
          attribute :include, default: -> { [] }

          validate :check_include_paths, if: -> { include.present? }
        end

        private

        def check_include_paths
          refuse_unknown(:include, Paths.new(include).reject { resource.paths_include?(it) })
        end
      end
    end
  end
end
