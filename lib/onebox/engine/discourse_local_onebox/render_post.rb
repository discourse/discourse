module Onebox
  module Engine
    class DiscourseLocalOnebox
      class RenderPost
        def self.call(options={})
          new(options).call
        end

        def initialize(options={})
          @post = options.fetch(:post)
        end

        def call
          PrettyText.cook(quote)
        end

        private
        attr_reader :post

        def topic
          post.topic
        end

        def slug
          Slug.for(topic.title)
        end

        def excerpt
          post.excerpt(SiteSetting.post_onebox_maxlength).tap do |text|
            text.gsub!("\n"," ")

            # hack to make it render for now
            text.gsub!("[/quote]", "[quote]")
          end
        end

        def quote
          %Q([quote="#{post.user.username}, topic:#{topic.id}, slug:#{slug}, post:#{post.post_number}"]#{excerpt}[/quote])
        end
      end
    end
  end
end
