# frozen_string_literal: true

module LocalizedFancyTopicTitleMixin
  def self.included(klass)
    klass.attributes :fancy_title
    klass.attributes :fancy_title_localized
    klass.attributes :locale
  end

  def fancy_title
    translated_title || _topic.fancy_title
  end

  def include_fancy_title?
    _topic.present? && _topic&.fancy_title.present?
  end

  def fancy_title_localized
    translated_title.present?
  end

  def include_fancy_title_localized?
    SiteSetting.content_localization_enabled && include_fancy_title?
  end

  def locale
    _topic.locale
  end

  def include_locale?
    SiteSetting.content_localization_enabled
  end

  private

  def _topic
    @_topic ||=
      if object.class == Topic
        object
      elsif defined?(topic) && topic.class == Topic
        topic
      elsif defined?(object.topic) && object.topic.class == Topic
        object.topic
      end
  end

  def translated_title
    ContentLocalization.show_translated_topic?(_topic, scope) &&
      _topic.get_localization&.fancy_title.presence
  end
end
