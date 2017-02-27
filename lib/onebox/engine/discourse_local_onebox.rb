module Onebox
  module Engine
    class DiscourseLocalOnebox
      include Engine

      # Use this onebox before others
      def self.priority
        1
      end

      def self.===(other)
        url = other.to_s
        return false unless url[Discourse.base_url]

        path = url.sub(Discourse.base_url, "")
        route = Rails.application.routes.recognize_path(path)

        !!(route[:controller] =~ /topics|uploads/)
      rescue ActionController::RoutingError
        false
      end

      def to_html
        path = @url.sub(Discourse.base_url, "")
        route = Rails.application.routes.recognize_path(path)

        case route[:controller]
        when "uploads" then upload_html(path)
        when "topics"  then topic_html(route)
        end
      end

      private

        def upload_html(path)
          case File.extname(path)
          when /^\.(mov|mp4|webm|ogv)$/i
            "<video width='100%' height='100%' controls><source src='#{@url}'><a href='#{@url}'>#{@url}</a></video>"
          when /^\.(mp3|ogg|wav|m4a)$/i
            "<audio controls><source src='#{@url}'><a href='#{@url}'>#{@url}</a></audio>"
          end
        end

        def topic_html(route)
          link = "<a href='#{@url}'>#{@url}</a>"
          source_topic_id = @url[/[&?]source_topic_id=(\d+)/, 1].to_i
          source_topic = Topic.find_by(id: source_topic_id) if source_topic_id > 0

          if route[:post_number].present? && route[:post_number].to_i > 1
            post = Post.find_by(topic_id: route[:topic_id], post_number: route[:post_number])
            return link unless can_see_post?(post, source_topic)

            topic = post.topic
            slug = Slug.for(topic.title)
            excerpt = post.excerpt(SiteSetting.post_onebox_maxlength)
            excerpt.gsub!(/[\r\n]+/, " ")
            excerpt.gsub!("[/quote]", "[quote]") # don't break my quote

            quote = "[quote=\"#{post.user.username}, topic:#{topic.id}, slug:#{slug}, post:#{post.post_number}\"]#{excerpt}[/quote]"

            args = {}
            args[:topic_id] = source_topic_id if source_topic_id > 0

            PrettyText.cook(quote, args)
          else
            topic = Topic.find_by(id: route[:topic_id])
            return link unless can_see_topic?(topic, source_topic)

            first_post = topic.ordered_posts.first

            args = {
              topic_id: topic.id,
              avatar: PrettyText.avatar_img(topic.user.avatar_template, "tiny"),
              original_url: @url,
              title: PrettyText.unescape_emoji(CGI::escapeHTML(topic.title)),
              category_html: CategoryBadge.html_for(topic.category),
              quote: first_post.excerpt(SiteSetting.post_onebox_maxlength),
            }

            template = File.read("#{Rails.root}/lib/onebox/templates/discourse_topic_onebox.hbs")
            Mustache.render(template, args)
          end
        end

        def can_see_post?(post, source_topic)
          return false if post.nil? || post.hidden || post.trashed? || post.topic.nil?
          Guardian.new.can_see_post?(post) || same_category?(post.topic.category, source_topic)
        end

        def can_see_topic?(topic, source_topic)
          return false if topic.nil? || topic.trashed? || topic.private_message?
          Guardian.new.can_see_topic?(topic) || same_category?(topic.category, source_topic)
        end

        def same_category?(category, source_topic)
          source_topic.try(:category_id) == category.try(:id)
        end

    end
  end
end
