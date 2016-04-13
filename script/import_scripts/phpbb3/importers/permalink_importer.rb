module ImportScripts::PhpBB3
  class PermalinkImporter
    POST_LINK_NORMALIZATION = '/(viewtopic.php\?)(?:.*&)?(p=\d+).*/\1\2'
    TOPIC_LINK_NORMALIZATION = '/(viewtopic.php\?)(?:.*&)?(t=\d+).*/\1\2'

    # @param settings [ImportScripts::PhpBB3::PermalinkSettings]
    def initialize(settings)
      @settings = settings
    end

    def change_site_settings
      normalizations = SiteSetting.permalink_normalizations
      normalizations = normalizations.blank? ? [] : normalizations.split('|')

      if @settings.create_post_links && !normalizations.include?(POST_LINK_NORMALIZATION)
        normalizations << POST_LINK_NORMALIZATION
      end

      if @settings.create_topic_links && !normalizations.include?(TOPIC_LINK_NORMALIZATION)
        normalizations << TOPIC_LINK_NORMALIZATION
      end

      SiteSetting.permalink_normalizations = normalizations.join('|')
    end

    def create_for_category(category, import_id)
      return unless @settings.create_category_links && category

      url = "viewforum.php?f=#{import_id}"

      if !Permalink.find_by(url: url)
        Permalink.create(url: url, category_id: category.id)
      end
    end

    def create_for_topic(topic, import_id)
      return unless @settings.create_topic_links && topic

      url = "viewtopic.php?t=#{import_id}"

      if !Permalink.find_by(url: url)
        Permalink.create(url: url, topic_id: topic.id)
      end
    end

    def create_for_post(post, import_id)
      return unless @settings.create_topic_links && post

      url = "viewtopic.php?p=#{import_id}"

      if !Permalink.find_by(url: url)
        Permalink.create(url: url, post_id: post.id)
      end
    end
  end
end
