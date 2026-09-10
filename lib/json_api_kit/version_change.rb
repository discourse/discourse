# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    CHANGES_DIRECTORY = Rails.root.join("config/api_changes")
    DATE_PREFIX = /\A\d{4}-\d{2}-\d{2}_/
    PASS_THROUGH = ->(_index, name) { PassThrough.new(name) }

    class << self
      def all = @all ||= read(CHANGES_DIRECTORY)

      def after(version) = all.select { it.version > version }

      def read(directory)
        Dir
          .glob(directory.join("*.rb"))
          .map { change_in(it) }
          .each(&:verify!)
          .sort_by { [it.version, it.source] }
      end

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

      private

      def change_in(source)
        constant = File.basename(source, ".rb").sub(DATE_PREFIX, "").camelize
        Object.send(:remove_const, constant) if Object.const_defined?(constant, false)
        load source
        constant.constantize.new(source)
      end
    end

    delegate :version, :description, :transformations, :type_renames, to: :class

    attr_reader :source

    def initialize(source)
      @source = source
      @upward = index_by(transformations, &:previous_names)
      @downward = index_by(transformations) { [it.current] }
      @type_upward = index_by(type_renames, &:previous_names)
      @type_downward = index_by(type_renames) { [it.current] }
    end

    def verify!
      raise ArgumentError, "#{source} has no version." if version.nil?
      raise ArgumentError, "#{source} is dated in the future." if version.future?
      if version <= Timeline::FIRST_RELEASE
        raise ArgumentError, "#{source} is dated on or before the first release."
      end
      raise ArgumentError, "#{source} has no description." if description.blank?
      duplicate_name(&:previous_names).try { raise ArgumentError, "#{source} changes #{it} twice." }
      duplicate_name { [it.current] }.try do
        raise ArgumentError, "#{source} changes two names into #{it}."
      end
      return if File.basename(source).start_with?(version.to_s)
      raise ArgumentError, "The file name must start with the version #{version}: #{source}."
    end

    def current(name) = upward[current_type(name)].current

    def current_attributes(attributes)
      current_values(attributes.transform_keys { current_type(it) })
    rescue Converter::Failure => failure
      raise failure.convert_names { previous_type(it) }
    end

    def previous(name) = previous_names(name).first

    def previous_names(name) = downward[name].previous_names.map { previous_type(it) }

    def previous_attributes(attributes)
      attributes
        .flat_map { |name, value| downward[name].previous_pairs(value) }
        .to_h
        .transform_keys { previous_type(it) }
    end

    private

    attr_reader :upward, :downward, :type_upward, :type_downward

    def current_type(name)
      name.convert_type { type_upward[Name::Type.new(value: it)].current.value }
    end

    def previous_type(name)
      name.convert_type { type_downward[Name::Type.new(value: it)].previous_names.first.value }
    end

    def current_values(attributes)
      attributes.keys.map { upward[it] }.uniq.flat_map { it.current_pairs(attributes) }.to_h
    end

    def index_by(transformations, &names)
      transformations
        .flat_map { |transformation| names.call(transformation).map { [it, transformation] } }
        .to_h
        .tap { it.default_proc = PASS_THROUGH }
    end

    def duplicate_name(&)
      (transformations + type_renames).flat_map(&).tally.detect { |_name, count| count > 1 }&.first
    end
  end
end
