# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class Converter < Conversion::Base
        def initialize(settings)
          super
          @source_db = Adapter::Postgres.new(settings[:source_db])
        end

        def step_args(step_class)
          { source_db: @source_db }
        end
      end
    end
  end
end
