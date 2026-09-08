# frozen_string_literal: true

module Boards
  class Board < ActiveRecord::Base
    include ::AclTarget

    self.table_name = "discourse_kanban_boards"
    self.ignored_columns = %w[
      base_filter_query
      show_activity_indicators
      allow_read_group_ids
      allow_write_group_ids
    ]

    has_many :columns,
             -> { order(:position, :id) },
             class_name: "Boards::Column",
             dependent: :destroy,
             inverse_of: :board
    has_many :cards, class_name: "Boards::Card", dependent: :destroy, inverse_of: :board
    has_many :history,
             -> { order(created_at: :asc) },
             class_name: "Boards::BoardHistory",
             inverse_of: :board
    belongs_to :created_by, class_name: "User"
    belongs_to :updated_by, class_name: "User", optional: true

    enum :card_style, { detailed: 0, simple: 1 }, default: :detailed

    validates :name, :slug, presence: true
    validates :slug, uniqueness: true

    validate :validate_category_ids
    validate :validate_tag_ids

    before_validation :normalize_slug

    def self.mandatory_acl
      [{ type: :group, id: Group::AUTO_GROUPS[:admins], permission: "manage" }]
    end

    def self.banned_acl
      [
        { type: :group, id: Group::AUTO_GROUPS[:anonymous_users], permission: "manage" },
        { type: :group, id: Group::AUTO_GROUPS[:anonymous_users], permission: "edit" },
        # Essentially a legacy group ID, don't want anyone to use it.
        { type: :group, id: Group::AUTO_GROUPS[:everyone], permission: "manage" },
        { type: :group, id: Group::AUTO_GROUPS[:everyone], permission: "edit" },
        { type: :group, id: Group::AUTO_GROUPS[:everyone], permission: "view" },
      ]
    end

    def self.loss_warning_permissions
      ["manage"]
    end

    def url
      "#{Discourse.base_url}/boards/#{slug}/#{id}"
    end

    def anonymous_can_read?
      permission_acl.group_has_permission?(Group::AUTO_GROUPS[:anonymous_users], "view")
    end

    def logged_in_user_can_read?
      permission_acl.group_has_any_permission?(
        Group::AUTO_GROUPS[:logged_in_users],
        %w[view edit manage],
      )
    end

    def can_be_oneboxed?
      if SiteSetting.login_required
        logged_in_user_can_read?
      else
        anonymous_can_read?
      end
    end

    def unicode_name
      Emoji.gsub_emoji_to_unicode(name)
    end

    def reload(options = nil)
      @tags = nil
      @categories = nil
      super
    end

    def tags
      @tags ||= Tag.where(id: tag_ids).order(:name).to_a
    end

    def categories
      @categories ||= Category.where(id: category_ids).order(:name).to_a
    end

    def self.preload_tags(boards)
      preload_array_association(boards, :tag_ids, :@tags, Tag)
    end

    def self.preload_categories(boards)
      preload_array_association(boards, :category_ids, :@categories, Category)
    end

    def self.preload_array_association(records, ids_attr, ivar, klass)
      records = Array(records)
      return records if records.empty?

      all_ids = records.flat_map(&ids_attr).uniq
      records_by_id = all_ids.empty? ? {} : klass.where(id: all_ids).index_by(&:id)

      records.each do |record|
        sorted =
          record
            .public_send(ids_attr)
            .filter_map { |id| records_by_id[id] }
            .sort_by { |r| r.name.to_s }
        record.instance_variable_set(ivar, sorted)
      end

      records
    end
    private_class_method :preload_array_association

    def tag_names=(names)
      names = Array(names).select(&:present?)
      resolved = Tag.where(name: names).pluck(:name, :id).to_h
      missing = names - resolved.keys
      if missing.any?
        raise Discourse::InvalidParameters.new(
                I18n.t("boards.errors.unknown_tag_names", tag_names: missing.join(", ")),
              )
      end
      self.tag_ids = resolved.values
    end

    def has_constraints?
      category_ids.present? || tag_ids.present?
    end

    def topic_matches?(topic)
      return false unless has_constraints?

      cat_match = category_ids.blank? || category_ids.include?(topic.category_id)
      tag_match = tag_ids.blank? || (topic.tag_ids & tag_ids).any?
      cat_match && tag_match
    end

    def topic_will_match_after_mutation?(topic, column)
      return true unless has_constraints?

      effective_category_id = column&.move_to_category_id || topic.category_id
      cat_match = category_ids.blank? || category_ids.include?(effective_category_id)

      effective_tag_ids = topic.tag_ids.dup
      if column
        column_tag_ids = columns.filter_map { |candidate| candidate.tag_id.presence }.uniq
        sibling_tag_ids = column_tag_ids - [column.tag_id].compact
        effective_tag_ids -= sibling_tag_ids
        effective_tag_ids << column.tag_id if column.tag_id.present?
        effective_tag_ids.uniq!
      end
      tag_match = tag_ids.blank? || (effective_tag_ids & tag_ids).any?

      cat_match && tag_match
    end

    def first_matching_column(topic)
      all_matching_columns(topic).first
    end

    def all_matching_columns(topic)
      return [] unless topic_matches?(topic)

      topic_tag_id_set = topic.tag_ids.to_set
      columns.select { |c| c.tag_id.present? && topic_tag_id_set.include?(c.tag_id) }
    end

    private

    def normalize_slug
      source = slug.presence || name
      self.slug = Slug.for(source) if source.present?
    end

    def normalize_id_array(values)
      Array(values).map(&:to_i).uniq.reject(&:zero?)
    end

    alias_method :normalize_group_array, :normalize_id_array

    def validate_category_ids
      return if category_ids.blank?

      self.category_ids = normalize_id_array(category_ids)
      existing = Category.where(id: category_ids).pluck(:id)
      missing = category_ids - existing
      return if missing.empty?

      errors.add(
        :base,
        I18n.t("boards.errors.unknown_category_ids", category_ids: missing.join(",")),
      )
    end

    def validate_tag_ids
      return if tag_ids.blank?

      self.tag_ids = normalize_id_array(tag_ids)
      existing = Tag.where(id: tag_ids).pluck(:id)
      missing = tag_ids - existing
      return if missing.empty?

      errors.add(:base, I18n.t("boards.errors.unknown_tag_ids", tag_ids: missing.join(",")))
    end
  end
end

# == Schema Information
#
# Table name: discourse_kanban_boards
#
#  id                   :bigint           not null, primary key
#  card_style           :integer          default("detailed"), not null
#  category_ids         :integer          default([]), not null, is an Array
#  name                 :string           not null
#  require_confirmation :boolean          default(TRUE), not null
#  show_tags            :boolean          default(FALSE), not null
#  show_topic_thumbnail :boolean          default(FALSE), not null
#  slug                 :string           not null
#  tag_ids              :integer          default([]), not null, is an Array
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  created_by_id        :bigint
#  updated_by_id        :bigint
#
# Indexes
#
#  idx_kanban_boards_category_ids                  (category_ids) USING gin
#  idx_kanban_boards_tag_ids                       (tag_ids) USING gin
#  index_discourse_kanban_boards_on_created_by_id  (created_by_id)
#  index_discourse_kanban_boards_on_slug           (slug) UNIQUE
#
