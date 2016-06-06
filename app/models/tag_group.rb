class TagGroup < ActiveRecord::Base
  has_many :tag_group_memberships, dependent: :destroy
  has_many :tags, through: :tag_group_memberships

  def tag_names=(tag_names_arg)
    DiscourseTagging.add_or_create_tags_by_name(self, tag_names_arg)
  end
end
