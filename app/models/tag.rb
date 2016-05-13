class Tag < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true
  has_many :topic_tags, dependent: :destroy
  has_many :topics, through: :topic_tags
  has_many :tag_users

  def self.tags_by_count_query(opts={})
    q = TopicTag.joins(:tag, :topic).group("topic_tags.tag_id, tags.name").order('count_all DESC')
    q = q.limit(opts[:limit]) if opts[:limit]
    q
  end

  def self.top_tags(limit_arg=nil)
    self.tags_by_count_query(limit: limit_arg || SiteSetting.max_tags_in_filter_list)
        .count
        .map {|name, count| name}
  end
end
