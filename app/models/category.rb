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

  has_one :category_search_data

  scope :latest, ->{ order('topic_count desc') }

  scope :secured, ->(guardian = nil) {
    ids = guardian.secure_category_ids if guardian
    if ids.present?
      where("NOT categories.secure or categories.id in (:cats)", cats: ids)
    else
      where("NOT categories.secure")
    end
  }

  delegate :post_template, to: 'self.class'

  attr_accessor :displayable_topics

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

      return if self.slug.blank?

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

  def group_names=(names)
    # this line bothers me, destroying in AR can not seem to be queued, thinking of extending it
    category_groups.destroy_all unless new_record?
    ids = Group.where(name: names.split(",")).pluck(:id)
    ids.each do |id|
      category_groups.build(group_id: id)
    end
  end

  def deny(group)
    if group == :all
      self.secure = true
    end
  end

  def allow(group)
    if group == :all
      self.secure = false
      # this is kind of annoying, there should be a clean way of queuing this stuff
      category_groups.destroy_all unless new_record?
    else
      groups.push(group)
    end
  end

  def secure_group_ids
    if self.secure
      groups.pluck("groups.id")
    end
  end

end

# == Schema Information
#
# Table name: categories
#
#  id              :integer          not null, primary key
#  name            :string(50)       not null
#  color           :string(6)        default("AB9364"), not null
#  topic_id        :integer
#  topic_count     :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :integer          not null
#  topics_year     :integer
#  topics_month    :integer
#  topics_week     :integer
#  slug            :string(255)      not null
#  description     :text
#  text_color      :string(6)        default("FFFFFF"), not null
#  hotness         :float            default(5.0), not null
#  secure          :boolean          default(FALSE), not null
#  auto_close_days :float
#
# Indexes
#
#  index_categories_on_forum_thread_count  (topic_count)
#  index_categories_on_name                (name) UNIQUE
#

