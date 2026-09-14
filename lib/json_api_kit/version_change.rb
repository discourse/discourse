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
        transformations.concat(Declarations.new(type).tap { it.instance_eval(&declarations) }.to_a)
      end

      def transformations = @transformations ||= []

      def renamed_type(from:, to:)
        type_renames << TypeRename.new(
          from: Name::Type.new(value: from.to_s),
          to: Name::Type.new(value: to.to_s),
        )
      end

      def type_renames = @type_renames ||= []
    end

    delegate :version, :description, to: :class

    attr_reader :source

    def initialize(source)
      @source = source
      @transformations = Transformations.new(self.class.transformations)
      @type_renames = TypeRenames.new(self.class.type_renames)
    end

    def verify!
      raise ArgumentError, "#{source} has no version." if version.nil?
      raise ArgumentError, "#{source} is dated in the future." if version.future?
      if version <= Timeline::FIRST_RELEASE
        raise ArgumentError, "#{source} is dated on or before the first release."
      end
      raise ArgumentError, "#{source} has no description." if description.blank?
      transformations.verify!
      type_renames.verify!
      return if File.basename(source).start_with?(version.to_s)
      raise ArgumentError, "The file name must start with the version #{version}: #{source}."
    rescue NameChanges::Conflict => conflict
      raise ArgumentError, "#{source} #{conflict.message}"
    end

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

    private

    attr_reader :transformations, :type_renames

    def current_type(name) = name.convert_type { type_renames.current(it) }

    def previous_type(name) = name.convert_type { type_renames.previous(it) }
  end
end
