# frozen_string_literal: true

class PublishedPage < ActiveRecord::Base
  belongs_to :topic

  validates_presence_of :slug
  validates_uniqueness_of :slug, :topic_id

  validate :slug_format
  def slug_format
    if slug !~ /^[a-zA-Z\-\_0-9]+$/
      errors.add(:slug, I18n.t("publish_page.slug_errors.invalid"))
    elsif ["check-slug", "by-topic"].include?(slug)
      errors.add(:slug, I18n.t("publish_page.slug_errors.unavailable"))
    end
  end

  def path
    "/pub/#{slug}"
  end

  def url
    "#{Discourse.base_url}#{path}"
  end

  def self.publish!(publisher, topic, slug)
    transaction do
      pp = find_or_initialize_by(topic: topic)
      pp.slug = slug.strip

      if pp.save
        StaffActionLogger.new(publisher).log_published_page(topic.id, slug)
        return [true, pp]
      end
    end

    [false, pp]
  end

  def self.unpublish!(publisher, topic)
    if pp = PublishedPage.find_by(topic_id: topic.id)
      pp.destroy!
      StaffActionLogger.new(publisher).log_unpublished_page(topic.id, pp.slug)
    end
  end
end
