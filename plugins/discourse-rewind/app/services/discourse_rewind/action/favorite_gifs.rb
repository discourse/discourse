# frozen_string_literal: true

# Find the user's most used GIFs in posts and chat
# Ranks by usage count and engagement (likes/reactions)
module DiscourseRewind
  module Action
    class FavoriteGifs < BaseReport
      GIF_URL_PATTERN =
        %r{
          https?://[^\s]+\.(?:gif|gifv)
          |
          https?://(?!(?:developers|support|blog)\.) (?:[^/\s]+\.)?giphy\.com/(?!dashboard\b)[^\s]+
          |
          https?://(?!(?:support)\.) (?:[^/\s]+\.)?tenor\.com/(?!gifapi\b)[^\s]+
        }ix
      MAX_RESULTS = 5

      FakeData = {
        data: {
          favorite_gifs: [
            {
              url: "https://media.giphy.com/media/111ebonMs90YLu/giphy.gif",
              usage_count: 12,
              likes: 45,
              reactions: 23,
            },
            {
              url: "https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif",
              usage_count: 8,
              likes: 32,
              reactions: 18,
            },
            {
              url: "https://media1.tenor.com/m/XnODae53zvYAAAAd/joke-stickfigure.gif",
              usage_count: 7,
              likes: 28,
              reactions: 15,
            },
            {
              url: "https://c.tenor.com/tX_T48A14BwAAAAd/khaby-really.gif",
              usage_count: 5,
              likes: 20,
              reactions: 12,
            },
            {
              url: "https://media.giphy.com/media/3oriO0OEd9QIDdllqo/giphy.gif",
              usage_count: 4,
              likes: 15,
              reactions: 8,
            },
          ],
          total_gif_usage: 36,
        },
        identifier: "favorite-gifs",
      }

      def call
        return FakeData if Rails.env.development?
        gif_data = {}

        # Get GIFs from posts
        post_gifs = extract_gifs_from_posts
        post_gifs.each do |url, data|
          gif_data[url] ||= { url: url, usage_count: 0, likes: 0, reactions: 0 }
          gif_data[url][:usage_count] += data[:count]
          gif_data[url][:likes] += data[:likes]
        end

        # Get GIFs from chat messages if chat is enabled
        if Discourse.plugins_by_name["chat"]&.enabled?
          chat_gifs = extract_gifs_from_chat
          chat_gifs.each do |url, data|
            gif_data[url] ||= { url: url, usage_count: 0, likes: 0, reactions: 0 }
            gif_data[url][:usage_count] += data[:count]
            gif_data[url][:reactions] += data[:reactions]
          end
        end

        return if gif_data.empty?

        # Sort by engagement score (usage * 10 + likes + reactions)
        sorted_gifs =
          gif_data
            .values
            .sort_by { |gif| -(gif[:usage_count] * 10 + gif[:likes] + gif[:reactions]) }
            .first(MAX_RESULTS)

        {
          data: {
            favorite_gifs: sorted_gifs,
            total_gif_usage: gif_data.values.sum { |g| g[:usage_count] },
          },
          identifier: "favorite-gifs",
        }
      end

      private

      def extract_gifs_from_posts
        gif_usage = {}

        posts =
          Post
            .where(user_id: user.id)
            .where(created_at: date)
            .where(deleted_at: nil)
            .where("raw ~* ?", gif_sql_pattern)
            .select(:id, :raw, :like_count)

        posts.each do |post|
          gif_urls = post.raw.scan(GIF_URL_PATTERN).uniq.select { |url| content_gif_url?(url) }
          gif_urls.each do |url|
            gif_usage[url] ||= { count: 0, likes: 0 }
            gif_usage[url][:count] += 1
            gif_usage[url][:likes] += post.like_count || 0
          end
        end

        gif_usage
      end

      def extract_gifs_from_chat
        gif_usage = {}

        messages =
          Chat::Message
            .where(user_id: user.id)
            .where(created_at: date)
            .where(deleted_at: nil)
            .where("message ~* ?", gif_sql_pattern)
            .select(:id, :message)

        messages.each do |message|
          gif_urls =
            message.message.scan(GIF_URL_PATTERN).uniq.select { |url| content_gif_url?(url) }
          gif_urls.each do |url|
            gif_usage[url] ||= { count: 0, reactions: 0 }
            gif_usage[url][:count] += 1

            # Count reactions on this message
            reaction_count = Chat::MessageReaction.where(chat_message_id: message.id).count
            gif_usage[url][:reactions] += reaction_count
          end
        end

        gif_usage
      end

      def gif_sql_pattern
        @gif_sql_pattern ||= GIF_URL_PATTERN.source.gsub(/\s+/, "")
      end

      def content_gif_url?(url)
        return true if url.match?(/\.(gif|gifv)(?:\?|$)/i)
        return true if url.match?(%r{giphy\.com/(?:gifs?|media|embed|stickers|clips)}i)
        return true if url.match?(%r{tenor\.com/(?:view|watch|embed|gif)}i)

        false
      end
    end
  end
end
