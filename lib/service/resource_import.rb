# frozen_string_literal: true

module Service
  class ResourceImport
    def initialize(resource, only: nil, except: nil)
      raise ArgumentError, "only and except cannot be used together." if only && except
      if !resource && (only || except)
        raise ArgumentError, "#{only ? :only : :except} requires from_resource."
      end

      @attributes = resource ? resource.writable_attributes.index_by(&:name) : {}
      @included_names = only&.map(&:to_s) || attributes.keys
      @excluded_names = (except || []).map(&:to_s)
      verify_names!
    end

    def apply_to(contract)
      selected_attributes.each_value { contract.attribute(it.name, it.type) }
    end

    private

    attr_reader :attributes, :included_names, :excluded_names

    def selected_attributes = attributes.slice(*(included_names - excluded_names))

    def unknown_names = (included_names + excluded_names) - attributes.keys

    def verify_names!
      return if unknown_names.empty?
      raise ArgumentError, "#{unknown_names.join(", ")}: not writable resource attributes."
    end
  end
end
