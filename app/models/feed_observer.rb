require_dependency 'pubsubhubbub_hub'

class FeedObserver < ActiveRecord::Observer
  observe :post, :topic

  def after_create(model)
    urls = []
    Discourse.anonymous_filters.each do |filter|
      urls.push "#{Discourse.base_url}/#{filter}.rss" # All latest topics
    end

    if defined? model.topic
      urls.push "#{Discourse.base_url}#{model.topic.relative_url}.rss" # Topic feed url

      if model.topic.category
        urls.push "#{Discourse.base_url}/category/#{model.topic.category.slug}.rss" # Topic's Category feed url

        if model.topic.category.parent_category
          urls.push "#{Discourse.base_url}/category/#{model.topic.category.parent_category.slug}.rss" # All ancestor categories feed urls which will include the new model
        end
      end
    end

    PubSubHubbubHub.ping(urls)
  end
end
