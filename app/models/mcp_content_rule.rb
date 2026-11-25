# frozen_string_literal: true

# One row per active MCP content rule kind. A missing row means the rule kind is
# inactive. DiscourseMcp::ContentPolicy reads these rows on every MCP request.
class McpContentRule < ActiveRecord::Base
  belongs_to :updated_by, class_name: "User", optional: true

  # Serializes rule saves with the deletes and moves the rule guards check,
  # so a target can't disappear between a rule's check and its commit.
  GUARD_LOCK_KEY = 7_304_118_552

  validates :rule_kind, presence: true, uniqueness: true, length: { maximum: 200 }
  validate :listed_targets_exist, if: -> { rule_kind == DiscourseMcp::ForumContentRule::NAME }

  # Takes the lock that serializes rule saves with guarded deletes and moves,
  # held until the current transaction ends.
  #
  # @returns [void]
  def self.lock_guarded_targets!
    DB.exec("SELECT pg_advisory_xact_lock(:key)", key: GUARD_LOCK_KEY)
  end

  # Tags that a rule lists, plus the tags they are synonyms of. Removing one,
  # or turning it into a synonym, would silently change what the rule covers.
  #
  # @returns [Set<Integer>]
  def self.protected_tag_ids
    ids = listed_ids("tag_ids")
    return ids if ids.empty?

    ids | Tag.where(id: ids.to_a).where.not(target_tag_id: nil).pluck(:target_tag_id)
  end

  # Tags that a rule lists.
  #
  # @returns [Set<Integer>]
  def self.listed_tag_ids
    listed_ids("tag_ids")
  end

  # Categories that a rule lists, plus every category inside a denied one.
  # Deleting one would drop its denial, since its topics are only soft-deleted.
  #
  # @returns [Set<Integer>]
  def self.protected_category_ids
    listed_ids("category_ids") | denied_subtree_ids
  end

  # @returns [Set<Integer>] The denied categories and all their descendants.
  def self.denied_subtree_ids
    denied = denied_category_ids
    return denied if denied.empty?

    DB.query_single(DiscourseMcp::ForumContentRule::SUBTREE_SQL, ids: denied.to_a).to_set
  end

  # @returns [Set<Integer>]
  def self.denied_category_ids
    forum_configs.flat_map { |config| Array(config.dig("deny", "category_ids")) }.map(&:to_i).to_set
  end

  def self.listed_ids(key)
    forum_configs.map { |config| config_ids(config, key) }.reduce(Set.new, :|)
  end
  private_class_method :listed_ids

  # @param config [Hash, nil] A forum_content config.
  # @param key [String] "tag_ids" or "category_ids".
  # @returns [Set<Integer>] The ids that config lists under both sides.
  def self.config_ids(config, key)
    return Set.new if !config.is_a?(Hash)

    %w[allow deny].flat_map { |side| Array(config.dig(side, key)) }.map(&:to_i).to_set
  end

  def self.forum_configs
    where(rule_kind: DiscourseMcp::ForumContentRule::NAME)
      .pluck(:config)
      .select { |config| config.is_a?(Hash) }
  end
  private_class_method :forum_configs

  private

  # Only targets added by this save are checked, so a rule that already lists
  # a missing target can still be edited. The stored config is read again
  # after taking the lock, because this instance's copy may be stale.
  def listed_targets_exist
    self.class.lock_guarded_targets!
    previous =
      if persisted?
        self.class.where(id: id, rule_kind: DiscourseMcp::ForumContentRule::NAME).pick(:config)
      end
    { Tag => "tag_ids", Category => "category_ids" }.each do |model, key|
      added = (self.class.config_ids(config, key) - self.class.config_ids(previous, key)).to_a
      next if added.empty? || model.where(id: added).count == added.size

      errors.add(:config, I18n.t("mcp.errors.content_rule_target_missing"))
    end
  end
end

# == Schema Information
#
# Table name: mcp_content_rules
#
#  id            :bigint           not null, primary key
#  config        :jsonb            not null
#  rule_kind     :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  updated_by_id :integer
#
# Indexes
#
#  index_mcp_content_rules_on_rule_kind  (rule_kind) UNIQUE
#
