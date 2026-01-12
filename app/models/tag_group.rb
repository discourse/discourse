# frozen_string_literal: true

class TagGroup < ActiveRecord::Base
  validates :name, length: { maximum: 100 }
  validates :name, uniqueness: { case_sensitive: false }
  validates :slug, uniqueness: { case_sensitive: false }, allow_blank: true

  has_many :tag_group_memberships, dependent: :destroy
  has_many :tags, through: :tag_group_memberships
  has_many :none_synonym_tags,
           -> { where(target_tag_id: nil) },
           through: :tag_group_memberships,
           source: "tag"
  has_many :category_tag_groups, dependent: :destroy
  has_many :category_required_tag_groups, dependent: :destroy
  has_many :categories, through: :category_tag_groups
  has_many :tag_group_permissions, dependent: :destroy

  belongs_to :parent_tag, class_name: "Tag"

  before_validation :ensure_slug
  before_save :apply_permissions
  before_save :remove_parent_from_group
  before_create :init_permissions

  after_commit { DiscourseTagging.clear_cache! }

  attr_reader :permissions

  def tag_names=(tag_names_arg)
    DiscourseTagging.add_or_create_tags_by_name(self, tag_names_arg, unlimited: true)
  end

  def parent_tag_name=(tag_names_arg)
    if tag_names_arg.empty?
      self.parent_tag = nil
    else
      if tag_name =
           DiscourseTagging.tags_for_saving(
             tag_names_arg,
             Guardian.new(Discourse.system_user),
           ).first
        self.parent_tag = Tag.find_by_name(tag_name) || Tag.create(name: tag_name)
      end
    end
  end

  def permissions=(permissions)
    @permissions = TagGroup.resolve_permissions(permissions)
  end

  def self.find_id_by_slug(slug)
    return nil if slug.blank?

    result = where("LOWER(slug) = ?", slug.downcase).pick(:id)
    return result if result

    if (match = slug.match(/\A(\d+)-tag-group\z/))
      return match[1].to_i if exists?(id: match[1].to_i)
    end

    nil
  end

  # Same as Tag#find_by_name
  def self.find_by_name_insensitive(name)
    self.find_by("lower(name) = ?", name.downcase)
  end

  def self.resolve_permissions(permissions)
    permissions.map do |group, permission|
      group_id = Group.group_id_from_param(group)
      permission =
        if permission.is_a?(Integer)
          permission
        else
          TagGroupPermission.permission_types[permission.to_sym]
        end
      [group_id, permission]
    end
  end

  def init_permissions
    unless tag_group_permissions.present? || @permissions
      tag_group_permissions.build(
        group_id: Group::AUTO_GROUPS[:everyone],
        permission_type: TagGroupPermission.permission_types[:full],
      )
    end
  end

  def apply_permissions
    if @permissions
      tag_group_permissions.destroy_all
      @permissions.each do |group_id, permission_type|
        tag_group_permissions.build(group_id: group_id, permission_type: permission_type)
      end
      @permissions = nil
    end
  end

  def ensure_slug
    self.slug ||= ""
    return if name.blank?

    if slug.present?
      self.slug = Slug.for(slug, "", method: :encoded)

      if slug.blank?
        errors.add(:slug, :invalid)
      elsif SiteSetting.slug_generation_method == "ascii" && !CGI.unescape(slug).ascii_only?
        errors.add(:slug, I18n.t("tag_group.errors.slug_contains_non_ascii_chars"))
      elsif duplicate_slug?
        errors.add(:slug, I18n.t("tag_group.errors.slug_already_in_use"))
      end
    else
      self.slug = Slug.for(name, "")
      self.slug = "" if duplicate_slug?
    end
  end

  def duplicate_slug?
    return false if slug.blank?
    scope = TagGroup.where("LOWER(slug) = ?", slug.downcase)
    scope = scope.where.not(id: id) if id.present?
    scope.exists?
  end

  def slug_for_url
    slug.presence || "#{id}-tag-group"
  end

  def remove_parent_from_group
    tags.delete(parent_tag) if tags.include?(parent_tag)
  end

  def self.visible(guardian)
    if guardian.is_staff?
      TagGroup
    else
      # (
      #   tag group is restricted to a category you can see
      #   OR
      #   tag group is not restricted to any categories
      # )
      # AND tag group can be seen by everyone
      filter_sql = <<~SQL
        (
          id IN (SELECT tag_group_id FROM category_tag_groups WHERE category_id IN (?))
          OR
          id NOT IN (SELECT tag_group_id FROM category_tag_groups)
        )
        AND id IN (SELECT tag_group_id FROM tag_group_permissions WHERE group_id IN (?))
      SQL

      TagGroup.where(
        filter_sql,
        guardian.allowed_category_ids,
        DiscourseTagging.permitted_group_ids(guardian),
      )
    end
  end
end

# == Schema Information
#
# Table name: tag_groups
#
#  id            :integer          not null, primary key
#  name          :string(100)      not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  parent_tag_id :integer
#  one_per_topic :boolean          default(FALSE)
#
# Indexes
#
#  index_tag_groups_on_lower_name  (lower((name)::text)) UNIQUE
#
