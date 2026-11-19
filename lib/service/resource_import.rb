# frozen_string_literal: true

module Service
  class ResourceImport
    def initialize(resource, only: nil, except: nil)
      raise ArgumentError, "only and except cannot be used together." if only && except
      if !resource && (only || except)
        raise ArgumentError, "#{only ? :only : :except} requires from_resource."
      end

      @resource = resource
      @included_names = only&.map(&:to_s) || fields.keys
      @excluded_names = (except || []).map(&:to_s)
      verify_names!
      verify_parameter_names!
    end

    def apply_to(contract)
      selected_fields.each { it.apply_to(contract) }
    end

    private

    attr_reader :resource, :included_names, :excluded_names

    def fields
      @fields ||=
        if resource
          [
            *resource.writable_attributes.map { Field.new(it) },
            *resource.writable_relationships.map { Relationship.new(it) },
          ].group_by(&:parameter_name)
        else
          {}
        end
    end

    def selected_fields = fields.slice(*(included_names - excluded_names)).values.flatten

    def unknown_names = (included_names + excluded_names) - fields.keys

    def verify_names!
      return if unknown_names.empty?
      raise ArgumentError, "#{unknown_names.join(", ")}: not writable resource parameters."
    end

    def verify_parameter_names!
      return if repeated_parameters.empty?
      raise ArgumentError,
            "#{repeated_parameters.join(", ")}: mapped by more than one writable resource field."
    end

    def repeated_parameters =
      selected_fields.map(&:parameter_name).tally.filter_map { |name, count| name if count > 1 }
  end
end
