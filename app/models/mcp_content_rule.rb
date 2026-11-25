# frozen_string_literal: true

# One row per active MCP content rule kind. A missing row means the rule kind is
# inactive. DiscourseMcp::ContentPolicy reads these rows on every MCP request.
class McpContentRule < ActiveRecord::Base
  belongs_to :updated_by, class_name: "User", optional: true

  validates :rule_kind, presence: true, uniqueness: true, length: { maximum: 200 }

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
    forum_configs
      .flat_map { |config| Array(config.dig("allow", key)) + Array(config.dig("deny", key)) }
      .map(&:to_i)
      .to_set
  end
  private_class_method :listed_ids

  def self.forum_configs
    where(rule_kind: DiscourseMcp::ForumContentRule::NAME)
      .pluck(:config)
      .select { |config| config.is_a?(Hash) }
  end
  private_class_method :forum_configs
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
