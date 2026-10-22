# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class << self
      def version(raw = nil)
        @version = ApiVersion.parse(raw) if raw
        @version
      rescue ApiVersion::NotADate
        raise ArgumentError, "The version of #{self}, #{raw}, is not a date."
      end

      def description(text = nil)
        @description = text if text
        @description
      end

      def resource(type, &declarations)
        Declarations
          .new(type)
          .tap { it.instance_eval(&declarations) }
          .then do
            transformations.concat(it.transformations)
            default_sorts.concat(it.default_sorts)
            removed_filters.concat(it.removed_filters)
            removed_sorts.concat(it.removed_sorts)
            input_scope_changes.concat(it.input_scope_changes)
          end
      end

      def transformations = @transformations ||= []

      def renamed_type(from:, to:)
        type_renames << TypeRename.new(
          from: Name::Type.new(value: from.to_s),
          to: Name::Type.new(value: to.to_s),
        )
      end

      def type_renames = @type_renames ||= []

      def default_sorts = @default_sorts ||= []

      def removed_filters = @removed_filters ||= []

      def removed_sorts = @removed_sorts ||= []

      def input_scope_changes = @input_scope_changes ||= []
    end

    delegate :version, :description, to: :class

    attr_reader :source

    def initialize(source)
      @source = source
      @transformations = Transformations.new(self.class.transformations)
      @type_renames = TypeRenames.new(self.class.type_renames)
      @default_sorts = DefaultSorts.new(self.class.default_sorts)
      @removed_filters = RemovedFilters.new(self.class.removed_filters)
      @removed_sorts = RemovedSorts.new(self.class.removed_sorts)
      @input_scope_changes = InputScopeChanges.new(self.class.input_scope_changes)
    end

    def verify!
      raise ArgumentError, "#{source} has no version." if version.nil?
      raise ArgumentError, "#{source} is dated in the future." if version.future?
      if version <= Timeline::FIRST_RELEASE
        raise ArgumentError, "#{source} is dated on or before the first release."
      end
      raise ArgumentError, "#{source} has no description." if description.blank?
      [transformations, type_renames, default_sorts, input_scope_changes].each(&:verify!)
      return if File.basename(source).start_with?(version.to_s)
      raise ArgumentError, "The file name must start with the version #{version}: #{source}."
    rescue NameChanges::Conflict, DefaultSorts::Conflict, InputScopeChanges::Conflict => conflict
      raise ArgumentError, "#{source} #{conflict.message}"
    end

    def current_resource_type(type) = type_renames.current(type)

    def previous_resource_type(type) = type_renames.previous(type)

    def current_names(name) = transformations.current_names(current_type(name))

    def current_attributes(attributes)
      transformations.current_values(attributes.transform_keys { current_type(it) })
    rescue Converter::Failure => failure
      raise failure.convert_names { previous_type(it) }
    end

    def previous_names(name) = transformations.previous_names(name).map { previous_type(it) }

    def previous_attributes(attributes)
      transformations.previous_values(attributes).transform_keys { previous_type(it) }
    end

    def current_default_sort(default) = default.convert_names { current_names(it).sole }

    def each_removed_filter(type, collection = nil, &) =
      removed_filters.each_for(type, collection, &)

    def each_removed_sort(type, &) = removed_sorts.each_for(type, &)

    def each_input_scope_change(type, collection = nil, &)
      input_scope_changes.each_for(type, collection, &)
    end

    def each_current_default_sort(type)
      default_sorts.each_for(type) do |default|
        yield default.convert_names { transformations.current_names(it).sole }
      end
    end

    private

    attr_reader :transformations,
                :type_renames,
                :default_sorts,
                :removed_filters,
                :removed_sorts,
                :input_scope_changes

    def current_type(name) = name.convert_type { current_resource_type(it) }

    def previous_type(name) = name.convert_type { previous_resource_type(it) }
  end
end
