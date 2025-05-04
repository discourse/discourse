# frozen_string_literal: true

module Migrations::Importer
  class Step
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

      def depends_on(*step_names)
        steps_module = ::Migrations::Importer::Steps
        classes =
          step_names.map do |name|
            name = name.to_s.camelize
            klass = steps_module.const_get(name) if steps_module.const_defined?(name)

            unless klass.is_a?(Class) && klass < ::Migrations::Importer::Step
              raise NameError, "Class #{class_name} not found"
            end

            klass
          end

        @dependencies ||= []
        @dependencies.concat(classes)
      end

      def dependencies
        @dependencies || []
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

    def initialize(intermediate_db, discourse_db, shared_data)
      @intermediate_db = intermediate_db
      @discourse_db = discourse_db
      @shared_data = shared_data

      @stats = StepStats.new(skip_count: 0, warning_count: 0, error_count: 0)
    end

    def execute
      load_required_data
    end

    private

    def load_required_data
      required_mappings = self.class.required_mappings
      required_sets = self.class.required_sets
      return if required_mappings.blank? && required_sets.blank?

      print "    #{I18n.t("importer.loading_required_data")} "

      runtime =
        ::Migrations::DateHelper.track_time do
          required_mappings.each do |name, sql|
            instance_variable_set("@#{name}", @shared_data.load_mapping(sql))
          end

          required_sets.each do |name, sql|
            instance_variable_set("@#{name}", @shared_data.load_set(sql))
          end
        end

      puts ::Migrations::DateHelper.human_readable_time(runtime) if runtime >= 1
    end

    def update_progressbar(increment_by: 1)
      @progressbar.update(
        increment_by:,
        skip_count: @stats.skip_count,
        warning_count: @stats.warning_count,
        error_count: @stats.error_count,
      )
    end

    def with_progressbar(max_progress)
      ::Migrations::ExtendedProgressBar
        .new(max_progress:)
        .run do |progressbar|
          @progressbar = progressbar
          yield
          @progressbar = nil
        end
    end
  end
end
