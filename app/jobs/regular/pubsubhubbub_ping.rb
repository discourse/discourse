require_dependency 'pubsubhubbub_hub'

module Jobs

  class PubsubhubbubPing < Jobs::Base

    def execute(args)
      topic_id = args[:topic_id]
      post_id = args[:post_id]

      urls = []

      if topic_id
        Discourse.anonymous_filters.each do |filter|
          urls.push "#{Discourse.base_url}/#{filter}.rss" # All latest topics
        end
      end

      if post_id
        post = Post.where(id: post_id).first

        if post
          urls.push "#{Discourse.base_url}#{post.topic.relative_url}.rss" # Topic feed url

          if post.topic.category
            urls.push "#{Discourse.base_url}/category/#{post.topic.category.slug}.rss" # Topic's Category feed url
            if post.topic.category.parent_category
              urls.push "#{Discourse.base_url}/category/#{post.topic.category.parent_category.slug}.rss" # All ancestor categories feed urls which will include the new post
            end
          end
        end
      end

      PubSubHubbubHub.ping(urls)
    end
  end
end
