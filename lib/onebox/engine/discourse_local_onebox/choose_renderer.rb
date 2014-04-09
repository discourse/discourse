require_relative 'render_link'
require_relative 'render_post'
require_relative 'render_topic'

module Onebox
  module Engine
    class DiscourseLocalOnebox
      class ChooseRenderer
        def self.call(options={})
          new(options).call
        end

        def initialize(options={})
          @url = options.fetch(:url)
        end

        def call
          return unless valid_route?

          if post_link?
            render_post
          else
            render_topic
          end
        end

        private
        attr_reader :url, :route

        def valid_route?
          route && route[:controller] == 'topics'
        end

        def render_post
          post ? RenderPost.new(post: post) : RenderLink.new(url: url)
        end

        def render_topic
          topic ? RenderTopic.new(url: url, topic: topic) : RenderLink.new(url: url)
        end

        def route
          @route ||= begin
            uri = URI::parse(url)
            Rails.application.routes.recognize_path(uri.path)
          rescue ActionController::RoutingError
            nil
          end
        end

        def post_link?
          route[:post_number].present? && route[:post_number].to_i > 1
        end

        def post
          @post ||= begin
            post = Post.where(topic_id: route[:topic_id], post_number: route[:post_number].to_i).first
            post && Guardian.new.can_see?(post) ? post : nil
          end
        end

        def topic
          @topic ||= begin
            topic = Topic.where(id: route[:topic_id].to_i).includes(:user).first
            topic && Guardian.new.can_see?(topic) ? topic : nil
          end
        end
      end
    end
  end
end
