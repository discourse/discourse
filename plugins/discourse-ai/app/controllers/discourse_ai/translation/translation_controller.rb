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

        untranslated_posts = find_untranslated_posts(topic)

        if untranslated_posts.empty?
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
        begin
          RateLimiter.new(current_user, "ai_translate_post", 3, 5.minutes).performed!
        rescue RateLimiter::LimitExceeded
          render_json_error(I18n.t("rate_limiter.slow_down"))
        end
      end

      def find_untranslated_posts(topic)
        supported_locales = SiteSetting.content_localization_supported_locales.split("|")
        base_locales = supported_locales.map { |locale| locale.split("_").first }

        # Find posts that:
        # 1. Have a detected locale
        # 2. Need translation to other supported locales (excluding their own locale)
        # 3. Don't have PostLocalization records for those target locales yet
        # 4. Are not deleted and have content
        topic
          .posts
          .where("user_id > 0")
          .where.not(raw: "")
          .where(deleted_at: nil)
          .where.not(locale: nil)
          .where(
            "EXISTS (
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
