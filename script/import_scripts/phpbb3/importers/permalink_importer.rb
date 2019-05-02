# frozen_string_literal: true

module ImportScripts::PhpBB3
  class PermalinkImporter
    CATEGORY_LINK_NORMALIZATION = '/(viewforum.php\?)(?:.*&)?(f=\d+).*/\1\2'
    POST_LINK_NORMALIZATION = '/(viewtopic.php\?)(?:.*&)?(p=\d+).*/\1\2'
    TOPIC_LINK_NORMALIZATION = '/(viewtopic.php\?)(?:.*&)?(t=\d+).*/\1\2'

    # @param settings [ImportScripts::PhpBB3::PermalinkSettings]
    def initialize(settings)
      @settings = settings
    end

    def change_site_settings
      normalizations = SiteSetting.permalink_normalizations
      normalizations = normalizations.blank? ? [] : normalizations.split('|')

      add_normalization(normalizations, CATEGORY_LINK_NORMALIZATION) if @settings.create_category_links
      add_normalization(normalizations, POST_LINK_NORMALIZATION) if @settings.create_post_links
      add_normalization(normalizations, TOPIC_LINK_NORMALIZATION) if @settings.create_topic_links

      SiteSetting.permalink_normalizations = normalizations.join('|')
    end

    def create_for_category(category, import_id)
      return unless @settings.create_category_links && category

      url = "viewforum.php?f=#{import_id}"

      Permalink.create(url: url, category_id: category.id) unless permalink_exists(url)
    end

    def create_for_topic(topic, import_id)
      return unless @settings.create_topic_links && topic

      url = "viewtopic.php?t=#{import_id}"

      Permalink.create(url: url, topic_id: topic.id) unless permalink_exists(url)
    end

    def create_for_post(post, import_id)
      return unless @settings.create_topic_links && post

      url = "viewtopic.php?p=#{import_id}"

      Permalink.create(url: url, post_id: post.id) unless permalink_exists(url)
    end

    protected

    def add_normalization(normalizations, normalization)
      if @settings.normalization_prefix.present?
        prefix = @settings.normalization_prefix[%r|^/?(.*?)/?$|, 1]
        normalization = "/#{prefix.gsub('/', '\/')}\\#{normalization}"
      end

      normalizations << normalization unless normalizations.include?(normalization)
    end

    def permalink_exists(url)
      Permalink.find_by(url: url)
    end
  end
end
