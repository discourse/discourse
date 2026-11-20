# frozen_string_literal: true

module JsonApiKit
  class VersionChanges
    include Enumerable

    CHANGES_DIRECTORY = Rails.root.join("config/api_changes")
    DATE_PREFIX = /\A\d{4}-\d{2}-\d{2}_/

    class << self
      def core = @core ||= load(CHANGES_DIRECTORY)

      def load(directory)
        new(
          Dir
            .glob(directory.join("*.rb"))
            .map { change_in(it) }
            .each(&:verify!)
            .sort_by { [it.version, it.source] },
        )
      end

      private

      def change_in(source)
        constant = File.basename(source, ".rb").sub(DATE_PREFIX, "").camelize
        Object.send(:remove_const, constant) if Object.const_defined?(constant, false)
        Kernel.load(source)
        constant.constantize.new(source)
      end
    end

    delegate :each, to: :changes

    def initialize(changes)
      @changes = changes
    end

    def after(version) = select { it.version > version }

    private

    attr_reader :changes
  end
end
