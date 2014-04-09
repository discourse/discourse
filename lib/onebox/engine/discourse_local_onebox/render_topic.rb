module Onebox
  module Engine
    class DiscourseLocalOnebox
      class RenderTopic
        def self.call(options={})
          new(options).call
        end

        def initialize(options={})
          @url = options.fetch(:url)
          @topic = options.fetch(:topic)
        end

        def call
          Mustache.render(File.read(template_path), template_options)
        end

        private
        attr_reader :url, :topic

        def post
          @post ||= topic.posts.first
        end

        def category
          @category ||= topic.category
        end

        def category_html
          if category
            %Q("<a href="/category/#{category.slug}" class="badge badge-category" style="background-color: ##{category.color}; color: ##{category.text_color}">#{category.name}</a>")
          end
        end

        def posters
          @posters ||= topic.posters_summary.map do |p|
            {
              username: p[:user].username,
              avatar: PrettyText.avatar_img(p[:user].avatar_template, 'tiny'),
              description: p[:description],
              extras: p[:extras]
            }
          end
        end

        def quote
          post.excerpt(SiteSetting.post_onebox_maxlength)
        end

        def avatar
          PrettyText.avatar_img(topic.user.avatar_template, 'tiny')
        end

        def last_post
          FreedomPatches::Rails4.time_ago_in_words(topic.last_posted_at, false, scope: :'datetime.distance_in_words_verbose')
        end

        def age
          FreedomPatches::Rails4.time_ago_in_words(topic.created_at, false, scope: :'datetime.distance_in_words_verbose')
        end

        def template_path
          "#{Rails.root}/lib/onebox/templates/discourse_topic_onebox.handlebars"
        end

        def template_options
          {
            original_url: url,
            title: topic.title,
            avatar: avatar,
            posts_count: topic.posts_count,
            last_post: last_post,
            age: age,
            views: topic.views,
            posters: posters,
            quote: quote,
            category: category_html,
            topic: topic.id
          }
        end
      end
    end
  end
end
