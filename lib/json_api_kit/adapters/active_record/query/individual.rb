# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      class Query
        class Individual < Query
          def record
            records.first or raise NotFound
          end

          private

          def available_scope = super.where(schema.primary_key => request.id)
        end
      end
    end
  end
end
