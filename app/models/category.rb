class Category < ActiveRecord::Base
  belongs_to :topic, dependent: :destroy
  belongs_to :topic_only_relative_url,
    select: "id, title, slug",
    class_name: "Topic",
    foreign_key: "topic_id"
  belongs_to :user

  has_many :topics
  has_many :category_featured_topics
  has_many :featured_topics, through: :category_featured_topics, source: :topic

  has_many :category_featured_users
  has_many :featured_users, through: :category_featured_users, source: :user

  has_many :category_groups
  has_many :groups, through: :category_groups

  validates :user_id, presence: true
  validates :name, presence: true, uniqueness: true, length: { in: 1..50 }
  validate :uncategorized_validator

  before_validation :ensure_slug
  after_save :invalidate_site_cache
  after_create :create_category_definition
  after_create :publish_categories_list
  after_destroy :invalidate_site_cache
  after_destroy :publish_categories_list

  scope :latest, ->{ order('topic_count desc') }

  delegate :post_template, to: 'self.class'

  # Internal: Update category stats: # of topics in past year, month, week for
  # all categories.
  def self.update_stats
    topics = Topic
               .select("COUNT(*)")
               .where("topics.category_id = categories.id")
               .where("categories.topic_id <> topics.id")
               .visible

    topic_count = topics.to_sql
    topics_year = topics.created_since(1.year.ago).to_sql
    topics_month = topics.created_since(1.month.ago).to_sql
    topics_week = topics.created_since(1.week.ago).to_sql

    Category.update_all("topic_count = (#{topic_count}),
                         topics_year = (#{topics_year}),
                         topics_month = (#{topics_month}),
                         topics_week = (#{topics_week})")
  end

  # Internal: Generate the text of post prompting to enter category
  # description.
  def self.post_template
    I18n.t("category.post_template", replace_paragraph: I18n.t("category.replace_paragraph"))
  end

  def create_category_definition
    create_topic!(title: I18n.t("category.topic_prefix", category: name), user: user, pinned_at: Time.now)
    update_column(:topic_id, topic.id)
    topic.update_column(:category_id, id)
    topic.posts.create(raw: post_template, user: user)
  end

  def topic_url
    topic_only_relative_url.try(:relative_url)
  end

  def ensure_slug
    if name.present?
      self.slug = Slug.for(name)

      # If a category with that slug already exists, set the slug to nil so the category can be found
      # another way.
      category = Category.where(slug: self.slug)
      category = category.where("id != ?", id) if id.present?
      self.slug = '' if category.exists?
    end
  end

  # Categories are cached in the site json, so the caches need to be
  # invalidated whenever the category changes.
  def invalidate_site_cache
    Site.invalidate_cache
  end

  def publish_categories_list
    MessageBus.publish('/categories', {categories: ActiveModel::ArraySerializer.new(Category.latest.all).as_json})
  end

  def uncategorized_validator
    errors.add(:name, I18n.t(:is_reserved)) if name == SiteSetting.uncategorized_name
    errors.add(:slug, I18n.t(:is_reserved)) if slug == SiteSetting.uncategorized_name
  end

  def secure?
    self.secure
  end

  def deny(group)
    if group == :all
      self.secure = true
    end
  end

  def allow(group)
    if group == :all
      self.secure = false
      category_groups.clear
    else
      groups.push(group)
    end
  end

end
