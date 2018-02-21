class TagGroup < ActiveRecord::Base
  validates_uniqueness_of :name, case_sensitive: false

  has_many :tag_group_memberships, dependent: :destroy
  has_many :tags, through: :tag_group_memberships
  has_many :category_tag_groups, dependent: :destroy
  has_many :categories, through: :category_tag_groups

  belongs_to :parent_tag, class_name: 'Tag'

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

  def self.allowed(guardian)
    if guardian.is_staff?
      TagGroup
    else
      category_permissions_filter = <<~SQL
        id IN ( SELECT tag_group_id FROM category_tag_groups WHERE category_id IN (?))
        OR id NOT IN (SELECT tag_group_id FROM category_tag_groups)
      SQL

      TagGroup.where(category_permissions_filter, guardian.allowed_category_ids)
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
