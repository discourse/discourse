class Category < ActiveRecord::Base
  belongs_to :topic, dependent: :destroy
  belongs_to :topic_only_relative_url,
    select: "id, title",
    class_name: "Topic",
    foreign_key: "topic_id"
  belongs_to :user

  has_many :topics
  has_many :category_featured_topics
  has_many :featured_topics, through: :category_featured_topics, source: :topic

  has_many :category_featured_users
  has_many :featured_users, through: :category_featured_users, source: :user

  validates :user_id, presence: true
  validates :name, presence: true, uniqueness: true
  validate :uncategorized_validator

  before_save :ensure_slug
  after_save :invalidate_site_cache
  after_create :create_category_definition
  after_destroy :invalidate_site_cache

  scope :popular, ->{ order('topic_count desc') }

  delegate :post_template, to: 'self.class'

  def create_category_definition
    create_topic(title: I18n.t("category.topic_prefix", category: name), user: user, pinned_at: Time.now)
    update_column(:topic_id, topic.id)
    topic.update_column(:category_id, id)
    topic.posts.create(raw: post_template, user: user)
  end

  def topic_url
    topic_only_relative_url.try(:relative_url)
  end

  def ensure_slug
    self.slug = Slug.for(name)
  end

  # Categories are cached in the site json, so the caches need to be
  # invalidated whenever the category changes.
  def invalidate_site_cache
    Site.invalidate_cache
  end

  def uncategorized_validator
    errors.add(:name, I18n.t(:is_reserved)) if name == SiteSetting.uncategorized_name
    errors.add(:slug, I18n.t(:is_reserved)) if slug == SiteSetting.uncategorized_name
  end

  # Internal: Update category stats: # of topics in past year, month, week for
  # all categories.
  def self.update_stats
    topics = Topic
               .select("COUNT(*)")
               .where("topics.category_id = categories.id")
               .where("categories.topic_id <> topics.id")
               .visible

    topics_year = topics.created_since(1.year.ago).to_sql
    topics_month = topics.created_since(1.month.ago).to_sql
    topics_week = topics.created_since(1.week.ago).to_sql

    Category.update_all("topics_year = (#{topics_year}),
                         topics_month = (#{topics_month}),
                         topics_week = (#{topics_week})")
  end

  # Internal: Generate the text of post prompting to enter category
  # description.
  def self.post_template
    I18n.t("category.post_template", replace_paragraph: I18n.t("category.replace_paragraph"))
  end
end
