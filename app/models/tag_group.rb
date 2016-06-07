class TagGroup < ActiveRecord::Base
  validates_uniqueness_of :name, case_sensitive: false

  has_many :tag_group_memberships, dependent: :destroy
  has_many :tags, through: :tag_group_memberships
  has_many :category_tag_groups, dependent: :destroy
  has_many :categories, through: :category_tag_groups

  def tag_names=(tag_names_arg)
    DiscourseTagging.add_or_create_tags_by_name(self, tag_names_arg)
  end
end
