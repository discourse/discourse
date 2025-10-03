# frozen_string_literal: true

module DiscourseNarrativeBot
  class AdvancedUserNarrative < Base
    I18N_KEY = "discourse_narrative_bot.advanced_user_narrative"
    BADGE_NAME = "Licensed"

    TRANSITION_TABLE = {
      begin: {
        next_state: :tutorial_edit,
        next_instructions: Proc.new { I18n.t("#{I18N_KEY}.edit.instructions", i18n_post_args) },
        init: {
          action: :start_advanced_track,
        },
      },
      tutorial_edit: {
        next_state: :tutorial_delete,
        next_instructions: Proc.new { I18n.t("#{I18N_KEY}.delete.instructions", i18n_post_args) },
        edit: {
          action: :reply_to_edit,
        },
        reply: {
          next_state: :tutorial_edit,
          action: :missing_edit,
        },
      },
      tutorial_delete: {
        next_state: :tutorial_recover,
        next_instructions: Proc.new { I18n.t("#{I18N_KEY}.recover.instructions", i18n_post_args) },
        delete: {
          action: :reply_to_delete,
        },
        reply: {
          next_state: :tutorial_delete,
          action: :missing_delete,
        },
      },
      tutorial_recover: {
        next_state: :tutorial_category_hashtag,
        next_instructions:
          Proc.new do
            category = Category.secured(@user.guardian).last
            I18n.t(
              "#{I18N_KEY}.category_hashtag.instructions",
              i18n_post_args(category: "##{category.slug_ref}"),
            )
          end,
        recover: {
          action: :reply_to_recover,
        },
        reply: {
          next_state: :tutorial_recover,
          action: :missing_recover,
        },
      },
      tutorial_category_hashtag: {
        next_state: :tutorial_change_topic_notification_level,
        next_instructions:
          Proc.new do
            I18n.t("#{I18N_KEY}.change_topic_notification_level.instructions", i18n_post_args)
          end,
        reply: {
          action: :reply_to_category_hashtag,
        },
      },
      tutorial_change_topic_notification_level: {
        next_state: :tutorial_poll,
        next_instructions: Proc.new { I18n.t("#{I18N_KEY}.poll.instructions", i18n_post_args) },
        topic_notification_level_changed: {
          action: :reply_to_topic_notification_level_changed,
        },
        reply: {
          next_state: :tutorial_change_topic_notification_level,
          action: :missing_topic_notification_level_change,
        },
      },
      tutorial_poll: {
        prerequisite:
          Proc.new do
            SiteSetting.poll_enabled &&
              @user.in_any_groups?(SiteSetting.poll_create_allowed_groups_map)
          end,
        next_state: :tutorial_details,
        next_instructions: Proc.new { I18n.t("#{I18N_KEY}.details.instructions", i18n_post_args) },
        reply: {
          action: :reply_to_poll,
        },
      },
      tutorial_details: {
        next_state: :end,
        reply: {
          action: :reply_to_details,
        },
      },
    }

    def self.badge_name
      BADGE_NAME
    end

    def self.reset_trigger
      I18n.t("discourse_narrative_bot.advanced_user_narrative.reset_trigger")
    end

    def reset_bot(user, post)
      if pm_to_bot?(post)
        reset_data(user, topic_id: post.topic_id)
      else
        reset_data(user)
      end

      Jobs.enqueue_in(2.seconds, :narrative_init, user_id: user.id, klass: self.class.to_s)
    end

    private

    def init_tutorial_edit
      data = get_data(@user)

      fake_delay

      post =
        PostCreator.create!(
          @user,
          raw:
            I18n.t(
              "#{I18N_KEY}.edit.bot_created_post_raw",
              i18n_post_args(discobot_username: self.discobot_username),
            ),
          topic_id: data[:topic_id],
          skip_bot: true,
          skip_validations: true,
        )

      set_state_data(:post_id, post.id)
      post
    end

    def init_tutorial_recover
      data = get_data(@user)

      post =
        PostCreator.create!(
          @user,
          raw:
            I18n.t(
              "#{I18N_KEY}.recover.deleted_post_raw",
              i18n_post_args(discobot_username: self.discobot_username),
            ),
          topic_id: data[:topic_id],
          skip_bot: true,
          skip_validations: true,
        )

      set_state_data(:post_id, post.id)

      opts = { skip_bot: true }

      if SiteSetting.delete_removed_posts_after < 1
        opts[:delete_removed_posts_after] = 1

        result = PostActionCreator.notify_moderators(self.discobot_user, post)
        result.reviewable.perform(self.discobot_user, :ignore_and_do_nothing)
      end

      PostDestroyer.new(@user, post, opts).destroy
    end

    def start_advanced_track
      raw = I18n.t("#{I18N_KEY}.start_message", i18n_post_args(username: @user.username))

      raw = <<~MD
      #{raw}

      #{instance_eval(&@next_instructions)}
      MD

      opts = {
        title: I18n.t("#{I18N_KEY}.title"),
        target_usernames: @user.username,
        archetype: Archetype.private_message,
      }

      if @data[:topic_id]
        opts = opts.merge(topic_id: @data[:topic_id]).except(:title, :target_usernames, :archetype)
      end
      post = reply_to(@post, raw, opts)

      @data[:topic_id] = post.topic_id
      @data[:track] = self.class.to_s
      post
    end

    def reply_to_edit
      return unless valid_topic?(@post.topic_id)

      fake_delay

      raw = <<~MD
      #{I18n.t("#{I18N_KEY}.edit.reply", i18n_post_args)}

      #{instance_eval(&@next_instructions)}
      MD

      reply_to(@post, raw)
    end

    def missing_edit
      post_id = get_state_data(:post_id)
      return unless valid_topic?(@post.topic_id) && post_id != @post.id

      fake_delay

      unless @data[:attempted]
        reply_to(
          @post,
          I18n.t("#{I18N_KEY}.edit.not_found", i18n_post_args(url: Post.find_by(id: post_id).url)),
        )
      end

      enqueue_timeout_job(@user)
      false
    end

    def reply_to_delete
      return unless valid_topic?(@topic_id)

      fake_delay

      raw = <<~MD
      #{I18n.t("#{I18N_KEY}.delete.reply", i18n_post_args)}

      #{instance_eval(&@next_instructions)}
      MD

      PostCreator.create!(self.discobot_user, raw: raw, topic_id: @topic_id)
    end

    def missing_delete
      return unless valid_topic?(@post.topic_id)
      fake_delay
      unless @data[:attempted]
        reply_to(@post, I18n.t("#{I18N_KEY}.delete.not_found", i18n_post_args))
      end
      enqueue_timeout_job(@user)
      false
    end

    def reply_to_recover
      return unless valid_topic?(@post.topic_id)

      fake_delay

      raw = <<~MD
      #{I18n.t("#{I18N_KEY}.recover.reply", i18n_post_args(deletion_after: SiteSetting.delete_removed_posts_after))}

      #{instance_eval(&@next_instructions)}
      MD

      PostCreator.create!(self.discobot_user, raw: raw, topic_id: @post.topic_id)
    end

    def missing_recover
      unless valid_topic?(@post.topic_id) &&
               post_id = get_state_data(:post_id) && @post.id != post_id
        return
      end

      fake_delay
      unless @data[:attempted]
        reply_to(@post, I18n.t("#{I18N_KEY}.recover.not_found", i18n_post_args))
      end
      enqueue_timeout_job(@user)
      false
    end

    def reply_to_category_hashtag
      topic_id = @post.topic_id
      return unless valid_topic?(topic_id)

      if Nokogiri::HTML5.fragment(@post.cooked).css(".hashtag-cooked").size > 0
        raw = <<~MD
          #{I18n.t("#{I18N_KEY}.category_hashtag.reply", i18n_post_args)}

          #{instance_eval(&@next_instructions)}
        MD

        fake_delay
        reply_to(@post, raw)
      else
        fake_delay
        unless @data[:attempted]
          reply_to(@post, I18n.t("#{I18N_KEY}.category_hashtag.not_found", i18n_post_args))
        end
        enqueue_timeout_job(@user)
        false
      end
    end

    def missing_topic_notification_level_change
      return unless valid_topic?(@post.topic_id)

      fake_delay
      unless @data[:attempted]
        reply_to(
          @post,
          I18n.t("#{I18N_KEY}.change_topic_notification_level.not_found", i18n_post_args),
        )
      end
      enqueue_timeout_job(@user)
      false
    end

    def reply_to_topic_notification_level_changed
      return unless valid_topic?(@topic_id)

      fake_delay
      raw = <<~MD
        #{I18n.t("#{I18N_KEY}.change_topic_notification_level.reply", i18n_post_args)}

        #{instance_eval(&@next_instructions)}
      MD

      fake_delay

      post = PostCreator.create!(self.discobot_user, raw: raw, topic_id: @topic_id)

      enqueue_timeout_job(@user)
      post
    end

    def reply_to_poll
      topic_id = @post.topic_id
      return unless valid_topic?(topic_id)

      if Nokogiri::HTML5.fragment(@post.cooked).css(".poll").size > 0
        raw = <<~MD
          #{I18n.t("#{I18N_KEY}.poll.reply", i18n_post_args)}

          #{instance_eval(&@next_instructions)}
        MD

        fake_delay
        reply_to(@post, raw)
      else
        fake_delay
        unless @data[:attempted]
          reply_to(@post, I18n.t("#{I18N_KEY}.poll.not_found", i18n_post_args))
        end
        enqueue_timeout_job(@user)
        false
      end
    end

    def reply_to_details
      topic_id = @post.topic_id
      return unless valid_topic?(topic_id)

      fake_delay

      if Nokogiri::HTML5.fragment(@post.cooked).css("details").size > 0
        reply_to(@post, I18n.t("#{I18N_KEY}.details.reply", i18n_post_args))
      else
        unless @data[:attempted]
          reply_to(@post, I18n.t("#{I18N_KEY}.details.not_found", i18n_post_args))
        end
        enqueue_timeout_job(@user)
        false
      end
    end

    def reply_to_wiki
      topic_id = @post.topic_id
      return unless valid_topic?(topic_id)

      fake_delay

      if @post.wiki
        reply_to(@post, I18n.t("#{I18N_KEY}.wiki.reply", i18n_post_args))
      else
        unless @data[:attempted]
          reply_to(@post, I18n.t("#{I18N_KEY}.wiki.not_found", i18n_post_args))
        end
        enqueue_timeout_job(@user)
        false
      end
    end

    def end_reply
      fake_delay

      reply_to(
        @post,
        I18n.t("#{I18N_KEY}.end.message", i18n_post_args(certificate: certificate("advanced"))),
      )
    end

    def synchronize(user)
      if Rails.env.test?
        yield
      else
        DistributedMutex.synchronize("advanced_user_narrative_#{user.id}") { yield }
      end
    end
  end
end
