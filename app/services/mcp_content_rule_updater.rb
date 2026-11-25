# frozen_string_literal: true

# Saves and deletes MCP content rules for the admin page, and records each
# change in the staff action log with the primitives it switched off.
class McpContentRuleUpdater
  # @param actor [User]
  # @param rule_kind [String] A registered, available rule kind.
  # @param config [Hash] The config, in the shape the admin page sends.
  # @returns [McpContentRule]
  def self.save!(actor:, rule_kind:, config:)
    new(actor:, rule_kind:).save!(config)
  end

  # @param actor [User]
  # @param rule_kind [String] Any stored rule kind, registered or not.
  # @returns [void]
  def self.delete!(actor:, rule_kind:)
    new(actor:, rule_kind:).delete!
  end

  def initialize(actor:, rule_kind:)
    @actor = actor
    @rule_kind = rule_kind.to_s
  end

  def save!(config)
    kind = DiscourseMcp.registry.content_rule_kind(rule_kind)
    raise Discourse::NotFound if kind.nil? || !available?(kind)

    config = normalize(config.to_h.deep_stringify_keys)
    raise Discourse::InvalidParameters.new(:config) if !kind.config_schema.valid?(config)

    McpContentRule.transaction do
      McpContentRule.lock_guarded_targets!
      report = DiscourseMcp::ContentRestrictionsReport.new
      before = report.blocked_ids(DiscourseMcp::ContentPolicy.load)

      rule = McpContentRule.find_or_initialize_by(rule_kind:)
      previous = rule.persisted? ? rule.config : nil
      rule.assign_attributes(config:, updated_by: actor, updated_at: Time.zone.now)
      rule.save!

      disabled = report.blocked_ids(DiscourseMcp::ContentPolicy.load) - before
      log(
        "mcp_content_rule_updated",
        disabled_primitives: disabled.join(", "),
        previous_value: previous&.to_json,
        new_value: rule.config.to_json,
      )
      rule
    end
  end

  def delete!
    McpContentRule.transaction do
      rule = McpContentRule.lock.find_by(rule_kind:)
      raise Discourse::NotFound if rule.nil?

      rule.destroy!
      log("mcp_content_rule_deleted", previous_value: rule.config.to_json)
    end
  end

  private

  attr_reader :actor, :rule_kind

  # The forum rule's lists name tags, which are stored by id. An unknown name
  # is refused rather than created. A synonym is stored as the tag it stands
  # for, because topics carry that tag instead.
  def normalize(config)
    return config if rule_kind != DiscourseMcp::ForumContentRule::NAME

    %w[allow deny].each do |side|
      next if !config[side].is_a?(Hash) || !config[side].key?("tag_names")

      names = config[side].delete("tag_names")
      # Names replace the ids, so sending both, or anything but a list of
      # names, would silently drop part of the rule.
      if config[side].key?("tag_ids") || !names.is_a?(Array) ||
           !names.all? { |name| name.is_a?(String) }
        raise Discourse::InvalidParameters.new(:tag_names)
      end

      tags =
        Tag
          .where_name(names)
          .pluck(:name, :id, :target_tag_id)
          .to_h { |name, id, target_id| [name.downcase, target_id || id] }
      missing = names.reject { |name| tags.key?(name.downcase) }
      if missing.present?
        raise Discourse::InvalidParameters.new(
                I18n.t("mcp.errors.content_rule_unknown_tags", tags: missing.join(", ")),
              )
      end

      config[side]["tag_ids"] = names.map { |name| tags.fetch(name.downcase) }.uniq
    end
    canonicalize_tag_ids(config)
  end

  # Stores a synonym's id as the tag it stands for. Ids that match no tag are
  # kept, so validation still reports them as missing.
  def canonicalize_tag_ids(config)
    %w[allow deny].each do |side|
      ids = config[side].is_a?(Hash) ? config[side]["tag_ids"] : nil
      next if !ids.is_a?(Array) || !ids.all? { |id| id.is_a?(Integer) }

      targets = Tag.where(id: ids).where.not(target_tag_id: nil).pluck(:id, :target_tag_id).to_h
      config[side]["tag_ids"] = ids.map { |id| targets.fetch(id, id) }.uniq
    end
    config
  end

  def available?(kind)
    kind.available?
  rescue StandardError
    false
  end

  def log(action, details = {})
    StaffActionLogger.new(actor).log_custom(action, rule_kind:, **details)
  end
end
