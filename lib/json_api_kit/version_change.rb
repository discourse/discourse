# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    CHANGES_DIRECTORY = Rails.root.join("config/api_changes")
    DATE_PREFIX = /\A\d{4}-\d{2}-\d{2}_/

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

      private

      def change_in(source)
        constant = File.basename(source, ".rb").sub(DATE_PREFIX, "").camelize
        Object.send(:remove_const, constant) if Object.const_defined?(constant, false)
        load source
        constant.constantize.new(source)
      end
    end

    delegate :version, :description, :transformations, to: :class

    attr_reader :source

    def initialize(source)
      @source = source
    end

    def verify!
      raise ArgumentError, "#{source} has no version." if version.nil?
      raise ArgumentError, "#{source} is dated in the future." if version.future?
      if version <= Timeline::FIRST_RELEASE
        raise ArgumentError, "#{source} is dated on or before the first release."
      end
      raise ArgumentError, "#{source} has no description." if description.blank?
      return if File.basename(source).start_with?(version.to_s)
      raise ArgumentError, "The file name must start with the version #{version}: #{source}."
    end

    def current(name)
      transformations.reduce(name) { |result, transformation| transformation.current(result) }
    end

    def previous(name)
      transformations
        .reverse_each
        .reduce(name) { |result, transformation| transformation.previous(result) }
    end

    def introduces?(name) = transformations.any? { it.introduces?(name) }
  end
end
