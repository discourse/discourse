class Category < ActiveRecord::Base

  belongs_to :topic
  belongs_to :user

  has_many :topics
  has_many :category_featured_topics
  has_many :featured_topics, through: :category_featured_topics, source: :topic

  has_many :category_featured_users
  has_many :featured_users, through: :category_featured_users, source: :user

  validates_presence_of :user_id
  validates_presence_of :name
  validates_uniqueness_of :name
  validate :uncategorized_validator

  after_save :invalidate_site_cache
  after_destroy :invalidate_site_cache

  def uncategorized_validator
    return errors.add(:name, I18n.t(:is_reserved)) if name == SiteSetting.uncategorized_name
    return errors.add(:slug, I18n.t(:is_reserved)) if slug == SiteSetting.uncategorized_name
  end

  def self.popular
    order('topic_count desc')
  end
  
  # Recalculates `topics_year`, `topics_month`, and `topics_week`
  # for each Category.
  def self.update_stats
    topics = Topic
               .select("COUNT(*)")
               .where("topics.category_id = categories.id")
               .visible

    topics_year = topics.created_since(1.year.ago).to_sql
    topics_month = topics.created_since(1.month.ago).to_sql
    topics_week = topics.created_since(1.week.ago).to_sql
    
    Category.update_all("topics_year = (#{topics_year}), 
                         topics_month = (#{topics_month}), 
                         topics_week = (#{topics_week})")
  end

  # Use the first paragraph of the topic's first post as the excerpt
  def excerpt
    if topic.present?
      first_post = topic.posts.order(:post_number).first
      body = first_post.cooked
      matches = body.scan(/\<p\>(.*)\<\/p\>/)
      if matches and matches[0] and matches[0][0]
        return matches[0][0]
      end
    end
    nil
  end

  def topic_url
    topic.try(:relative_url)
  end

  before_save do
    self.slug = Slug.for(self.name)
  end

  after_create do
    topic = Topic.create!(title: I18n.t("category.topic_prefix", category: name), user: user, visible: false)
    topic.posts.create!(raw: SiteSetting.category_post_template, user: user)
    update_column(:topic_id, topic.id)
    topic.update_column(:category_id, self.id)
  end

  # We cache the categories in the site json, so we need to invalidate it when they change
  def invalidate_site_cache
    Site.invalidate_cache
  end

  before_destroy do
    topic.destroy
  end

end
