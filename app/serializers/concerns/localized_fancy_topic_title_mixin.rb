# frozen_string_literal: true

module LocalizedFancyTopicTitleMixin
  def self.included(klass)
    klass.attributes :fancy_title
  end

  def fancy_title
    f = _topic.fancy_title

    if (ContentLocalization.show_translated_topic?(_topic, scope))
      _topic.get_localization&.fancy_title.presence || f
    else
      f
    end
  end

  def include_fancy_title?
    _topic.present? && _topic&.fancy_title.present?
  end

  private

  def _topic
    return object if object.class == Topic
    return topic if defined?(topic) && topic.class == Topic
    object.topic if defined?(object.topic) && object.topic.class == Topic
  end
end
