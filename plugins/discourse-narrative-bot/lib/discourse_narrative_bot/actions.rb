module DiscourseNarrativeBot
  module Actions
    extend ActiveSupport::Concern

    included do
      def self.discobot_user
        @discobot ||= User.find(-2)
      end
    end

    private

    def reply_to(post, raw, opts = {})
      if post
        default_opts = {
          raw: raw,
          topic_id: post.topic_id,
          reply_to_post_number: post.post_number
        }

        new_post = PostCreator.create!(self.class.discobot_user, default_opts.merge(opts))
        reset_rate_limits(post) if new_post
        new_post
      else
        PostCreator.create!(self.class.discobot_user, { raw: raw }.merge(opts))
      end
    end

    def reset_rate_limits(post)
      user = post.user
      data = DiscourseNarrativeBot::Store.get(user.id.to_s)

      return unless data

      key = "#{DiscourseNarrativeBot::PLUGIN_NAME}:reset-rate-limit:#{post.topic_id}:#{data['state']}"

      if !(count = $redis.get(key))
        count = 0

        duration =
          if user && user.new_user?
            SiteSetting.rate_limit_new_user_create_post
          else
            SiteSetting.rate_limit_create_post
          end

        $redis.setex(key, duration, count)
      end

      if count.to_i < 2
        post.default_rate_limiter.rollback!
        post.limit_posts_per_day&.rollback!
        $redis.incr(key)
      end
    end

    def fake_delay
      sleep(rand(2..3)) if Rails.env.production?
    end

    def bot_mentioned?(post)
      doc = Nokogiri::HTML.fragment(post.cooked)

      valid = false

      doc.css(".mention").each do |mention|
        valid = true if mention.text == "@#{self.class.discobot_user.username}"
      end

      valid
    end

    def reply_to_bot_post?(post)
      post&.reply_to_post && post.reply_to_post.user_id == -2
    end

    def pm_to_bot?(post)
      topic = post.topic
      return false if !topic

      topic.pm_with_non_human_user? &&
        topic.topic_allowed_users.where(user_id: -2).exists?
    end
  end
end
