# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TranslationController < ::ApplicationController
      include AiCreditLimitHandler

      requires_plugin PLUGIN_NAME

      before_action :ensure_logged_in
      before_action :check_permissions
      before_action :rate_limit!

      def translate
        post = Post.find_by(id: params[:post_id])
        raise ActiveRecord::RecordNotFound unless post
        guardian.ensure_can_see!(post)

        if DiscourseAi::Translation.enabled?
          Jobs.enqueue(:detect_translate_post, post_id: post.id, force: true)

          if post.is_first_post?
            Jobs.enqueue(:detect_translate_topic, topic_id: post.topic.id, force: true)
          end
        else
          return(
            render json:
                     failed_json.merge(error: I18n.t("discourse_ai.translation.errors.disabled")),
                   status: :bad_request
          )
        end

        render json: success_json
      end

      def schedule_topic
        topic = Topic.find_by(id: params[:topic_id])
        raise ActiveRecord::RecordNotFound unless topic

        unless DiscourseAi::Translation.enabled?
          return(
            render json:
                     failed_json.merge(error: I18n.t("discourse_ai.translation.errors.disabled")),
                   status: :bad_request
          )
        end

        guardian.ensure_can_see!(topic)

        untranslated_posts = find_untranslated_posts(topic, guardian)

        if !topic_needs_translation?(topic) && !untranslated_posts.exists?
          return(
            render_json_error(
              I18n.t("discourse_ai.translation.errors.all_posts_translated"),
              status: :unprocessable_entity,
            )
          )
        end

        Jobs.enqueue(:detect_translate_topic, topic_id: topic.id, force: true)

        untranslated_posts.each do |post|
          Jobs.enqueue(:detect_translate_post, post_id: post.id, force: true)
        end

        render json: success_json.merge(scheduled_posts: untranslated_posts.count)
      end

      private

      def check_permissions
        guardian.ensure_can_localize_content!
      end

      def rate_limit!
        RateLimiter.new(current_user, "ai_translate_post", 3, 5.minutes).performed!
      rescue RateLimiter::LimitExceeded
        render_json_error(I18n.t("rate_limiter.slow_down"))
      end

      def topic_needs_translation?(topic)
        locales = DiscourseAi::Translation.locales

        return false if locales.blank?
        return true if topic.locale.blank?

        locales.any? do |locale|
          next false if LocaleNormalizer.is_same?(locale, topic.locale)

          topic.get_localization(locale, fallback: false).nil?
        end
      end

      def find_untranslated_posts(topic, guardian)
        supported_locales = DiscourseAi::Translation.locales
        base_locales = supported_locales.map { |locale| locale.split("_").first }

        # Find posts that need locale detection or translation to another supported locale.
        posts = topic.posts.secured(guardian)
        posts =
          posts.where("posts.user_id > 0") unless SiteSetting.ai_translation_include_bot_content
        posts
          .where.not(raw: "")
          .where(deleted_at: nil)
          .where(
            "posts.locale IS NULL OR EXISTS (
              SELECT 1 FROM unnest(ARRAY[?]) AS target_locale
              WHERE split_part(posts.locale, '_', 1) != target_locale
              AND NOT EXISTS (
                SELECT 1 FROM post_localizations pl
                WHERE pl.post_id = posts.id
                AND split_part(pl.locale, '_', 1) = target_locale
              )
            )",
            base_locales,
          )
      end
    end
  end
end
