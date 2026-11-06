# frozen_string_literal: true

class Sitemap < ActiveRecord::Base
  RECENT_SITEMAP_NAME = "recent"
  NEWS_SITEMAP_NAME = "news"

  class << self
    def regenerate_sitemaps
      names_used = [RECENT_SITEMAP_NAME, NEWS_SITEMAP_NAME]

      names_used.each { |name| touch(name) }

      numbered_pages_last_posted_at.each do |page_name, last_posted_at|
        sitemap = find_or_initialize_by(name: page_name)
        sitemap.update!(last_posted_at: last_posted_at, enabled: true)
        Rails.cache.delete(sitemap.page_cache_key) if sitemap.saved_change_to_last_posted_at?
        names_used << page_name
      end

      where.not(name: names_used).update_all(enabled: false)
    end

    def touch(name)
      find_or_initialize_by(name: name).tap do |sitemap|
        sitemap.update!(last_posted_at: sitemap.last_posted_topic || 3.days.ago, enabled: true)
      end
    end

    # Every sitemap counts and lists its topics from this one query, so a
    # plugin that drops topics here keeps the number of numbered pages and
    # their contents in step. A plugin that joins a table with several rows
    # per topic should add `distinct`, so each topic is listed and counted once.
    def indexable_topics
      topics =
        Topic.where(visible: true).joins(:category).where(categories: { read_restricted: false })

      DiscoursePluginRegistry.apply_modifier(:sitemap_topics_query, topics)
    end

    private

    # One pass over the listed topics gives every page's newest topic, so the cost
    # grows with the number of topics rather than with topics times pages.
    # A distinct relation comes from a plugin whose join repeats topics, and
    # DENSE_RANK numbers topics rather than rows so the repeats don't add pages.
    def numbered_pages_last_posted_at
      topics = indexable_topics
      rank = topics.distinct_value ? "DENSE_RANK()" : "ROW_NUMBER()"
      page_number =
        "(#{rank} OVER (ORDER BY topics.id) - 1) / #{SiteSetting.sitemap_page_size.to_i} + 1"
      pages = topics.select(:updated_at, "#{page_number} AS page")

      Topic
        .unscoped
        .from(pages, :pages)
        .group("pages.page")
        .pluck(Arel.sql("pages.page"), Arel.sql("MAX(pages.updated_at)"))
        .map { |page, last_posted_at| [page.to_s, last_posted_at] }
    end
  end

  def topics
    if name == RECENT_SITEMAP_NAME
      sitemap_topics.pluck(:id, :slug, :bumped_at, :updated_at, :posts_count)
    elsif name == NEWS_SITEMAP_NAME
      # A distinct relation must select what it orders by; the news template
      # ignores bumped_at.
      sitemap_topics.pluck(:id, :title, :slug, :created_at, :bumped_at)
    else
      sitemap_topics.pluck(:id, :slug, :bumped_at, :updated_at)
    end
  end

  def last_posted_topic
    sitemap_topics.maximum(:updated_at)
  end

  def max_page_size
    SiteSetting.sitemap_page_size
  end

  def page_cache_key
    "sitemap/#{name}/#{max_page_size}"
  end

  private

  def sitemap_topics
    indexable_topics = self.class.indexable_topics

    if name == RECENT_SITEMAP_NAME
      indexable_topics.where("bumped_at > ?", 3.days.ago).order(bumped_at: :desc)
    elsif name == NEWS_SITEMAP_NAME
      indexable_topics.where("bumped_at > ?", 72.hours.ago).order(bumped_at: :desc)
    else
      offset = (name.to_i - 1) * max_page_size

      indexable_topics.order(id: :asc).limit(max_page_size).offset(offset)
    end
  end
end

# == Schema Information
#
# Table name: sitemaps
#
#  id             :bigint           not null, primary key
#  enabled        :boolean          default(TRUE), not null
#  last_posted_at :datetime         not null
#  name           :string           not null
#
# Indexes
#
#  index_sitemaps_on_name  (name) UNIQUE
#
