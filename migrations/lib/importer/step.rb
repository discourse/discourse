# frozen_string_literal: true

module Migrations::Importer
  class Step
    class << self
      def title=(value)
        @title = value
      end

      def title
        @title ||=
          I18n.t(
            "importer.default_step_title",
            type: name&.demodulize&.underscore&.humanize(capitalize: false),
          )
      end

      def depends_on(*step_names)
        steps_module = ::Migrations::Importer::Steps
        classes =
          step_names.map do |name|
            name = name.to_s.capitalize
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
    end

    def initialize(intermediate_db, discourse_db)
      @intermediate_db = intermediate_db
      @discourse_db = discourse_db

      @stats = StepStats.new(skip_count: 0, warning_count: 0, error_count: 0)
    end

    def execute
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

    # private
    #
    # def max_progress
    #   nil
    # end
    #
    # def items
    # end
    #
    # def copy_data(sql, *parameters)
    #   with_progressbar
    #
    #   table_name = TABLE_NAME if defined?(TABLE_NAME)
    #   table_name ||= self.class.name&.demodulize&.underscore
    #
    #   column_names = @discourse_db.column_names(table_name).to_set
    #   column_names -= EXCLUDED_COLUMN_NAMES if defined?(EXCLUDED_COLUMN_NAMES)
    #
    #   items =
    #     Enumerator.new do |y|
    #       @intermediate_db.query(sql, *parameters) do |row|
    #         processed_row = process_row(row)
    #
    #         if processed_row
    #           y << processed_row
    #         else
    #           @stats.skip_count += 1
    #         end
    #
    #         @stats.progress += 1
    #         update_progressbar
    #       end
    #     end
    #
    #   @discourse_db.copy_data(table_name, column_names, items) { store_mappings }
    # ensure
    #   store_mappings
    # end
    #
    # def process_row(row)
    #   row
    # end
    #
    # def update_progressbar
    #   @progressbar.update(
    #     @stats.progress,
    #     skip_count: @stats.skip_count,
    #     warning_count: @stats.warning_count,
    #     error_count: @stats.error_count,
    #   )
    # end
    #
    # def store_mappings
    # end
    #
    # def with_progressbar
    #   ::Migrations::ExtendedProgressBar
    #     .new(max_progress:)
    #     .run do |progressbar|
    #       @progressbar = progressbar
    #       yield
    #       @progressbar = nil
    #     end
    # end

    # def define_process_row_method
    #   method_body = +""
    #
    #   method_body << <<~RUBY if @column_names.include?(:id)
    #       row[:original_id] = row[:id]
    #       row[:id] = @last_id += 1
    #     RUBY
    #
    #   method_body << "row[:created_at] ||= NOW" if @column_names.include?(:created_at)
    #
    #   if @column_names.include?(:updated_at)
    #     if @column_names.include?(:created_at)
    #       method_body << "row[:updated_at] ||= row[:created_at]"
    #     else
    #       method_body << "row[:updated_at] ||= NOW"
    #     end
    #   end
    #
    #   eval <<~RUBY
    #     def process_row(row)
    #       #{method_body}
    #     end
    #   RUBY
    # end
  end
end
