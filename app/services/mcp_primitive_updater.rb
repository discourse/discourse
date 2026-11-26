# frozen_string_literal: true

class McpPrimitiveUpdater
  def self.update!(actor:, primitive_ids:)
    new(actor:).update!(primitive_ids:)
  end

  def self.set_emergency_block!(actor:, primitive_id:, blocked:)
    new(actor:).set_emergency_block!(primitive_id:, blocked:)
  end

  def initialize(actor:)
    @actor = actor
  end

  def update!(primitive_ids:)
    @enabled_primitive_ids = Array(primitive_ids).map(&:to_s).to_set
    previously_exposed_consent_relevant_ids = exposed_consent_relevant_primitive_ids

    McpPrimitive.transaction do
      update_primitive_records!
      require_fresh_consent_for_new_exposure!(previously_exposed_consent_relevant_ids)
      StaffActionLogger.new(actor).log_custom(
        "mcp_primitives_updated",
        primitive_count: enabled_primitive_ids.length,
      )
    end
  end

  def set_emergency_block!(primitive_id:, blocked:)
    kind, identifier = primitive_id.to_s.split(":", 2)
    primitive = DiscourseMcp.registry.find(kind, identifier)
    raise Discourse::NotFound if primitive.blank?

    primitive_record = McpPrimitive.find_or_initialize_by(kind:, identifier:)
    McpPrimitive.transaction do
      was_exposed = primitive_record.exposed?
      primitive_record.assign_attributes(emergency_blocked: blocked)
      if primitive_record.changed?
        expands_consent_relevant_access =
          !was_exposed && primitive_record.exposed? && primitive.consent_relevant?
        primitive_record.consent_required_at = Time.zone.now if expands_consent_relevant_access
        primitive_record.save!
        if expands_consent_relevant_access
          McpOauthAuthorization.require_consent!(scopes: primitive.required_scopes)
        end
      end
      StaffActionLogger.new(actor).log_custom(
        "mcp_primitive_emergency_block_updated",
        primitive: primitive_id,
        blocked: primitive_record.emergency_blocked?,
      )
    end
    primitive_record
  end

  private

  attr_reader :actor, :enabled_primitive_ids

  def update_primitive_records!
    DiscourseMcp.registry.all.each do |primitive|
      primitive_record =
        McpPrimitive.find_or_initialize_by(kind: primitive.kind, identifier: primitive.identifier)
      primitive_record.enabled =
        enabled_primitive_ids.include?("#{primitive.kind}:#{primitive.identifier}")
      primitive_record.save!
    end
  end

  def require_fresh_consent_for_new_exposure!(previously_exposed_ids)
    newly_exposed_ids = exposed_consent_relevant_primitive_ids - previously_exposed_ids
    return if newly_exposed_ids.blank?

    invalidated_at = Time.zone.now
    McpPrimitive.where(id: newly_exposed_ids).update_all(
      consent_required_at: invalidated_at,
      updated_at: invalidated_at,
    )
    McpOauthAuthorization.require_consent!(scopes: scopes_for_primitive_records(newly_exposed_ids))
  end

  def exposed_consent_relevant_primitive_ids
    McpPrimitive
      .exposed
      .filter_map do |primitive_record|
        primitive = DiscourseMcp.registry.find(primitive_record.kind, primitive_record.identifier)
        primitive_record.id if primitive&.consent_relevant?
      end
      .to_set
  end

  def scopes_for_primitive_records(primitive_record_ids)
    McpPrimitive
      .where(id: primitive_record_ids)
      .flat_map do |primitive_record|
        DiscourseMcp
          .registry
          .find(primitive_record.kind, primitive_record.identifier)
          &.required_scopes || []
      end
      .uniq
  end
end
