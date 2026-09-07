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
      @upward = index_by(&:from)
      @downward = index_by(&:to)
    end

    def verify!
      raise ArgumentError, "#{source} has no version." if version.nil?
      raise ArgumentError, "#{source} is dated in the future." if version.future?
      if version <= Timeline::FIRST_RELEASE
        raise ArgumentError, "#{source} is dated on or before the first release."
      end
      raise ArgumentError, "#{source} has no description." if description.blank?
      duplicate_name(:from).try { raise ArgumentError, "#{source} renames #{it} twice." }
      duplicate_name(:to).try { raise ArgumentError, "#{source} renames two names to #{it}." }
      return if File.basename(source).start_with?(version.to_s)
      raise ArgumentError, "The file name must start with the version #{version}: #{source}."
    end

    def current(name) = upward[name].current

    def current_attributes(attributes)
      attributes.flat_map { |name, value| upward[name].current_pairs(value) }.to_h
    end

    def previous(name) = downward[name].previous

    def previous_attributes(attributes)
      attributes.flat_map { |name, value| downward[name].previous_pairs(value) }.to_h
    end

    private

    attr_reader :upward, :downward

    def index_by(&) = transformations.index_by(&).tap { it.default_proc = PASS_THROUGH }

    def duplicate_name(field)
      transformations.map(&field).tally.detect { |_name, count| count > 1 }&.first
    end
  end
end
