# frozen_string_literal: true

module LocalizationAttributesReplacer
  def self.replace_category_attributes(category, crawl_locale)
    if loc = get_localization(category, crawl_locale)
      category.name = loc.name if loc.name.present?
      category.description = loc.description if loc.description.present?
    end

    while category = category.parent_category
      replace_category_attributes(category, crawl_locale)
    end
  end

  def self.replace_topic_attributes(topic, crawl_locale)
    if loc = get_localization(topic, crawl_locale)
      # assigning directly to title would commit the change to the database
      # due to the setter method defined in the Topic model
      topic.send(:write_attribute, :title, loc.title) if loc.title.present?
      topic.excerpt = loc.excerpt if loc.excerpt.present?
    end

    replace_category_attributes(topic.category, crawl_locale) if topic&.category.present?
  end

  def self.replace_post_attributes(post, crawl_locale)
    if loc = get_localization(post, crawl_locale)
      post.cooked = loc.cooked if loc.cooked.present?
    end
  end

  private

  def self.get_localization(model, crawl_locale)
    model.present? && model.locale.present? &&
      !LocaleNormalizer.is_same?(model.locale, crawl_locale) && model.get_localization(crawl_locale)
  end
end
