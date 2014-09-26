module Onebox
  module Engine
    class DiscourseLocalOnebox
      include Engine

      matches_regexp Regexp.new("^#{Discourse.base_url.gsub(".","\\.")}.*$", true)

      # Use this onebox before others
      def self.priority
        1
      end

      def to_html
        uri = URI::parse(@url)
        route = Rails.application.routes.recognize_path(uri.path)

        args = {original_url: @url}

        # Figure out what kind of onebox to show based on the URL
        case route[:controller]
        when 'topics'

          linked = "<a href='#{@url}'>#{@url}</a>"
          if route[:post_number].present? && route[:post_number].to_i > 1
            # Post Link
            post = Post.find_by(topic_id: route[:topic_id], post_number: route[:post_number].to_i)
            return linked unless post
            return linked if post.hidden
            return linked unless Guardian.new.can_see?(post)

            topic = post.topic
            slug = Slug.for(topic.title)

            excerpt = post.excerpt(SiteSetting.post_onebox_maxlength)
            excerpt.gsub!("\n"," ")
            # hack to make it render for now
            excerpt.gsub!("[/quote]", "[quote]")
            quote = "[quote=\"#{post.user.username}, topic:#{topic.id}, slug:#{slug}, post:#{post.post_number}\"]#{excerpt}[/quote]"

            cooked = PrettyText.cook(quote)
            return cooked

          else
            # Topic Link
            topic = Topic.where(id: route[:topic_id].to_i).includes(:user).first
            return linked unless topic
            return linked unless Guardian.new.can_see?(topic)

            post = topic.posts.first

            posters = topic.posters_summary.map do |p|
              {
                username: p[:user].username,
                avatar: PrettyText.avatar_img(p[:user].avatar_template, 'tiny'),
                description: p[:description],
                extras: p[:extras]
              }
            end

            category_name = ''
            parent_category_name = ''
            category = topic.category
            if category && !category.uncategorized?
              category_name = "<a href=\"#{category.url}\" class=\"badge badge-category\" style=\"background-color: ##{category.color}; color: ##{category.text_color}\">#{category.name}</a>"
              if !category.parent_category_id.nil?
                parent_category = Category.find_by(id: category.parent_category_id)
                parent_category_name = "<a href=\"#{parent_category.url}\" class=\"badge badge-category\" style=\"background-color: ##{parent_category.color}; color: ##{parent_category.text_color}\">#{parent_category.name}</a>"
              end
            end

            quote = post.excerpt(SiteSetting.post_onebox_maxlength)
            args.merge! title: topic.title,
                        avatar: PrettyText.avatar_img(topic.user.avatar_template, 'tiny'),
                        posts_count: topic.posts_count,
                        last_post: FreedomPatches::Rails4.time_ago_in_words(topic.last_posted_at, false, scope: :'datetime.distance_in_words_verbose'),
                        age: FreedomPatches::Rails4.time_ago_in_words(topic.created_at, false, scope: :'datetime.distance_in_words_verbose'),
                        views: topic.views,
                        posters: posters,
                        quote: quote,
                        category_name: category_name,
                        parent_category_name: parent_category_name,
                        topic: topic.id

            @template = 'topic'
          end

        end

        return nil unless @template
        Mustache.render(File.read("#{Rails.root}/lib/onebox/templates/discourse_#{@template}_onebox.hbs"), args)
      rescue ActionController::RoutingError
        nil
      end

    end
  end
end
