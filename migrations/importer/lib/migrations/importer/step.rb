# frozen_string_literal: true

module Migrations
  module Importer
    class Step
      extend StepDependencies

      Enums = Database::IntermediateDB::Enums

      # Set by the executor before `execute` runs. Steps report progress and
      # notices through it; see `Migrations::Reporting::Reporter`.
      attr_accessor :reporter

      class << self
        # stree-ignore
        def title(value = (getter = true; nil))
          if getter
            return(
              @title ||=
                I18n.t(
                  "importer.default_step_title",
                  type: name&.demodulize&.underscore&.humanize(capitalize: false),
                )
            )
          end

          @title = value
        end

        def requires_shared_data(*names)
          @required_shared_data ||= []
          @required_shared_data += names
        end

        def required_shared_data
          @required_shared_data || []
        end

        def requires_mapping(name, sql)
          @required_mappings ||= {}
          @required_mappings[name] = sql
        end

        def required_mappings
          @required_mappings || {}
        end

        def requires_set(name, sql)
          @required_sets ||= {}
          @required_sets[name] = sql
        end

        def required_sets
          @required_sets || {}
        end
      end

      def initialize(intermediate_db, discourse_db, shared_data, config)
        @intermediate_db = intermediate_db
        @discourse_db = discourse_db
        @shared_data = shared_data
        @config = config

        @stats = StepStats.new(skip_count: 0, warning_count: 0, error_count: 0)

        setup
      end

      def execute
        load_required_data
      end

      private

      # Override in subclasses if necessary
      def setup
      end

      def load_required_data
        required_shared_data = self.class.required_shared_data
        required_mappings = self.class.required_mappings
        required_sets = self.class.required_sets
        return if required_shared_data.empty? && required_mappings.blank? && required_sets.blank?

        required_shared_data.each { |name| instance_variable_set("@#{name}", @shared_data[name]) }

        required_mappings.each do |name, sql|
          instance_variable_set("@#{name}", @shared_data.load_mapping(sql))
        end

        required_sets.each do |name, sql|
          instance_variable_set("@#{name}", @shared_data.load_set(sql))
        end
      end

      def notice(message)
        @reporter.notice(message)
      end

      def update_progressbar(increment_by: 1)
        @progress.update(
          increment_by:,
          skip_count: @stats.skip_count,
          warning_count: @stats.warning_count,
          error_count: @stats.error_count,
        )
      end

      def with_progressbar(max_progress)
        @reporter.with_progress(max_progress:) do |progress|
          @progress = progress
          yield
          @progress = nil
        end
      end
    end
  end
end
