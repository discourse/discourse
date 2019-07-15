# frozen_string_literal: true

class TagGroup < ActiveRecord::Base
  validates_uniqueness_of :name, case_sensitive: false

  has_many :tag_group_memberships, dependent: :destroy
  has_many :tags, through: :tag_group_memberships
  has_many :category_tag_groups, dependent: :destroy
  has_many :categories, through: :category_tag_groups
  has_many :tag_group_permissions, dependent: :destroy

  belongs_to :parent_tag, class_name: 'Tag'

  before_create :init_permissions
  before_save :apply_permissions

  after_commit { DiscourseTagging.clear_cache! }

  attr_accessor :permissions

  def tag_names=(tag_names_arg)
    DiscourseTagging.add_or_create_tags_by_name(self, tag_names_arg, unlimited: true)
  end

  def parent_tag_name=(tag_names_arg)
    if tag_names_arg.empty?
      self.parent_tag = nil
    else
      if tag_name = DiscourseTagging.tags_for_saving(tag_names_arg, Guardian.new(Discourse.system_user)).first
        self.parent_tag = Tag.find_by_name(tag_name) || Tag.create(name: tag_name)
      end
    end
  end

  def permissions=(permissions)
    @permissions = TagGroup.resolve_permissions(permissions)
  end

  # TODO: long term we can cache this if TONs of tag groups exist
  def self.find_id_by_slug(slug)
    self.pluck(:id, :name).each do |id, name|
      if Slug.for(name) == slug
        return id
      end
    end
    nil
  end

  def self.resolve_permissions(permissions)
    permissions.map do |group, permission|
      group_id = Group.group_id_from_param(group)
      permission = TagGroupPermission.permission_types[permission] unless permission.is_a?(Integer)
      [group_id, permission]
    end
  end

  def init_permissions
    unless tag_group_permissions.present? || @permissions
      tag_group_permissions.build(
        group_id: Group::AUTO_GROUPS[:everyone],
        permission_type: TagGroupPermission.permission_types[:full]
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
        AND id IN (SELECT tag_group_id FROM tag_group_permissions WHERE group_id = ?)
      SQL

      TagGroup.where(filter_sql, guardian.allowed_category_ids, Group::AUTO_GROUPS[:everyone])
    end
  end
end

# == Schema Information
#
# Table name: tag_groups
#
#  id            :integer          not null, primary key
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  parent_tag_id :integer
#  one_per_topic :boolean          default(FALSE)
#
