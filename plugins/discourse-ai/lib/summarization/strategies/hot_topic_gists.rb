# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class HotTopicGists < Base
        def type
          AiSummary.summary_types[:gist]
        end

        def feature
          "gists"
        end

        def highest_target_number
          target.highest_post_number
        end

        def targets_data
          op_post_number = 1

          hot_topics_recent_cutoff = Time.zone.now - SiteSetting.hot_topics_recent_days.days

          recent_hot_posts =
            Post
              .where(topic_id: target.id)
              .where("post_type = ?", Post.types[:regular])
              .where("NOT hidden")
              .where("created_at >= ?", hot_topics_recent_cutoff)
              .pluck(:post_number)

          # It may happen that a topic is hot without any recent posts
          # In that case, we'll just grab the last 20 posts
          # for an useful summary of the current state of the topic
          if recent_hot_posts.empty?
            recent_hot_posts =
              Post
                .where(topic_id: target.id)
                .where("post_type = ?", Post.types[:regular])
                .where("NOT hidden")
                .order("post_number DESC")
                .limit(20)
                .pluck(:post_number)
          end

          posts_data =
            Post
              .where(topic_id: target.id)
              .joins(:user)
              .where("post_number IN (?)", recent_hot_posts << op_post_number)
              .order(:post_number)
              .pluck(:post_number, :raw, :username, :last_version_at)

          posts_data.reduce([]) do |memo, (pn, raw, username, last_version_at)|
            raw_text = raw

            if pn == 1 && target.topic_embed&.embed_content_cache.present?
              raw_text = target.topic_embed&.embed_content_cache
            end

            memo << { poster: username, id: pn, text: raw_text, last_version_at: last_version_at }
          end
        end

        def as_llm_messages(contents)
          content_title = target.title
          statements =
            contents.to_a.map { |item| "(#{item[:id]} #{item[:poster]} said: #{item[:text]} " }

          context = +<<~TEXT
            ### Context:

            #{content_title.present? ? "The discussion title is: " + content_title + ". (DO NOT REPEAT THIS IN THE SUMMARY)\n" : ""}

            The conversation began with the following statement:

            #{statements.shift}\n
          TEXT

          if statements.present?
            context << <<~TEXT
              Subsequent discussion includes the following:

              #{statements.join("\n")}

              Your task is to focus on these latest messages, capturing their meaning in the context of the initial statement.
            TEXT
          else
            context << "Your task is to capture the meaning of the initial statement."
          end

          [{ type: :user, content: context }]
        end
      end
    end
  end
end
