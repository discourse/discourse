class Tag < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true

  has_many :tag_users # notification settings

  has_many :topic_tags, dependent: :destroy
  has_many :topics, through: :topic_tags

  has_many :category_tags, dependent: :destroy
  has_many :categories, through: :category_tags

  def self.tags_by_count_query(opts={})
    q = TopicTag.joins(:tag, :topic).group("topic_tags.tag_id, tags.name").order('count_all DESC')
    q = q.limit(opts[:limit]) if opts[:limit]
    q
  end

  def self.category_tags_by_count_query(category, opts={})
    tags_by_count_query(opts).where("tags.id in (select tag_id from category_tags where category_id = ?)", category.id)
                             .where("topics.category_id = ?", category.id)
  end

  def self.top_tags(limit_arg=nil)
    self.tags_by_count_query(limit: limit_arg || SiteSetting.max_tags_in_filter_list)
        .count
        .map {|name, count| name}
  end
end

# == Schema Information
#
# Table name: tags
#
#  id          :integer          not null, primary key
#  name        :string           not null
#  topic_count :integer          default(0), not null
#  created_at  :datetime
#  updated_at  :datetime
#
# Indexes
#
#  index_tags_on_name  (name) UNIQUE
#
