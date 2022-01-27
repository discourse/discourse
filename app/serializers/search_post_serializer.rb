# frozen_string_literal: true

class SearchPostSerializer < BasicPostSerializer
  has_one :topic, serializer: SearchTopicListItemSerializer

  attributes :like_count, :blurb, :post_number, :topic_title_headline

  def include_topic_title_headline?
    if SiteSetting.use_pg_headlines_for_excerpt
      object.topic_title_headline.present?
    else
      false
    end
  end

  def topic_title_headline
    object.topic_title_headline
  end

  def blurb
    options[:result].blurb(object)
  end

  def include_blurb?
    options[:result].present?
  end

  def include_cooked?
    false
  end

  def include_ignored?
    false
  end
end
