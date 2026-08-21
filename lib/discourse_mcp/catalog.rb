# frozen_string_literal: true

module DiscourseMcp
  class Catalog
    def initialize(profile:, principal:)
      @profile = profile
      @principal = principal
    end

    def list(kind)
      exposed(kind).select { |capability| principal.has_scopes?(capability.required_scopes) }
    end

    def find(kind, identifier)
      list(kind).find { |capability| capability.identifier == identifier.to_s }
    end

    def find_exposed(kind, identifier)
      exposed(kind).find { |capability| capability.identifier == identifier.to_s }
    end

    private

    attr_reader :profile, :principal

    def exposed(kind)
      policies =
        profile.capability_policies.exposed.where(kind: kind.to_s).pluck(:identifier).to_set

      DiscourseMcp
        .registry
        .all(kind)
        .select do |capability|
          policies.include?(capability.identifier) && capability.available? &&
            (capability.required_scopes - profile.allowed_scopes).empty? &&
            consent_current?(capability)
        end
    end

    def consent_current?(capability)
      return true if !capability.consent_relevant?

      principal.authorization.consent_revision >= profile.consent_revision
    end
  end
end
