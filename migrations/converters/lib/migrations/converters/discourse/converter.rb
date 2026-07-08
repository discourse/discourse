# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class Converter < Conversion::Base
        # Steps run concurrently and a Postgres connection can't be shared, so each
        # step gets its own adapter; the step's source closes it in its `cleanup`.
        def step_args(step_class)
          { source_db: Adapter::Postgres.new(settings[:source_db]) }
        end
      end
    end
  end
end
