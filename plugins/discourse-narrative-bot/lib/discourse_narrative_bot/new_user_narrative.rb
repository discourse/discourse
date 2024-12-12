# frozen_string_literal: true

require "distributed_mutex"

module DiscourseNarrativeBot
  class NewUserNarrative < Base
    I18N_KEY = "discourse_narrative_bot.new_user_narrative".freeze
    BADGE_NAME = "Certified".freeze

    TRANSITION_TABLE = {
      begin: {
        init: {
          next_state: :tutorial_bookmark,
          next_instructions:
            Proc.new { I18n.t("#{I18N_KEY}.bookmark.instructions", base_uri: Discourse.base_path) },
          action: :say_hello,
        },
      },
      tutorial_bookmark: {
        next_state: :tutorial_onebox,
        next_instructions:
          Proc.new { I18n.t("#{I18N_KEY}.onebox.instructions", base_uri: Discourse.base_path) },
        bookmark: {
          action: :reply_to_bookmark,
        },
        reply: {
          next_state: :tutorial_bookmark,
          action: :missing_bookmark,
        },
      },
      tutorial_onebox: {
        next_state: :tutorial_emoji,
        next_instructions:
          Proc.new { I18n.t("#{I18N_KEY}.emoji.instructions", base_uri: Discourse.base_path) },
        reply: {
          action: :reply_to_onebox,
        },
      },
      tutorial_emoji: {
        prerequisite: Proc.new { SiteSetting.enable_emoji },
        next_state: :tutorial_mention,
        next_instructions:
          Proc.new do
            I18n.t(
              "#{I18N_KEY}.mention.instructions",
              discobot_username: self.discobot_username,
              base_uri: Discourse.base_path,
            )
          end,
        reply: {
          action: :reply_to_emoji,
        },
      },
      tutorial_mention: {
        prerequisite: Proc.new { SiteSetting.enable_mentions },
        next_state: :tutorial_formatting,
        next_instructions:
          Proc.new { I18n.t("#{I18N_KEY}.formatting.instructions", base_uri: Discourse.base_path) },
        reply: {
          action: :reply_to_mention,
        },
      },
      tutorial_formatting: {
        next_state: :tutorial_quote,
        next_instructions:
          Proc.new { I18n.t("#{I18N_KEY}.quoting.instructions", base_uri: Discourse.base_path) },
        reply: {
          action: :reply_to_formatting,
        },
      },
      tutorial_quote: {
        next_state: :tutorial_images,
        next_instructions:
          Proc.new { I18n.t("#{I18N_KEY}.images.instructions", base_uri: Discourse.base_path) },
        reply: {
          action: :reply_to_quote,
        },
      },
      # Note: tutorial_images and tutorial_likes are mutually exclusive.
      #       The prerequisites should ensure only one of them is called.
      tutorial_images: {
        prerequisite:
          Proc.new { @user.in_any_groups?(SiteSetting.embedded_media_post_allowed_groups_map) },
        next_state: :tutorial_likes,
        next_instructions:
          Proc.new { I18n.t("#{I18N_KEY}.likes.instructions", base_uri: Discourse.base_path) },
        reply: {
          action: :reply_to_image,
        },
        like: {
          action: :track_images_like,
        },
      },
      tutorial_likes: {
        prerequisite:
          Proc.new { !@user.in_any_groups?(SiteSetting.embedded_media_post_allowed_groups_map) },
        next_state: :tutorial_flag,
        next_instructions:
          Proc.new do
            I18n.t(
              "#{I18N_KEY}.flag.instructions",
              guidelines_url: url_helpers(:guidelines_url),
              about_url: url_helpers(:about_index_url),
              base_uri: Discourse.base_path,
            )
          end,
        like: {
          action: :reply_to_likes,
        },
        reply: {
          next_state: :tutorial_likes,
          action: :missing_likes_like,
        },
      },
      tutorial_flag: {
        prerequisite: Proc.new { SiteSetting.allow_flagging_staff },
        next_state: :tutorial_search,
        next_instructions:
          Proc.new { I18n.t("#{I18N_KEY}.search.instructions", base_uri: Discourse.base_path) },
        flag: {
          action: :reply_to_flag,
        },
        reply: {
          next_state: :tutorial_flag,
          action: :missing_flag,
        },
      },
      tutorial_search: {
        next_state: :end,
        reply: {
          action: :reply_to_search,
        },
      },
    }

    def self.badge_name
      BADGE_NAME
    end

    def self.search_answer
      ":herb:"
    end

    def self.search_answer_emoji
      "\u{1F33F}"
    end

    def self.reset_trigger
      I18n.t("discourse_narrative_bot.new_user_narrative.reset_trigger")
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

    def synchronize(user)
      if Rails.env.test?
        yield
      else
        DistributedMutex.synchronize("new_user_narrative_#{user.id}") { yield }
      end
    end

    def init_tutorial_search
      topic = @post.topic
      post = topic.first_post

      raw = <<~MD
      #{post.raw}

      #{I18n.t("#{I18N_KEY}.search.hidden_message", i18n_post_args.merge(search_answer: NewUserNarrative.search_answer))}
      MD

      PostRevisor.new(post, topic).revise!(
        self.discobot_user,
        { raw: raw },
        skip_validations: true,
        force_new_version: true,
      )

      set_state_data(:post_version, post.reload.version || 0)
    end

    def clean_up_tutorial_search
      first_post = @post.topic.first_post
      first_post.revert_to(get_state_data(:post_version) - 1)
      first_post.save!
      first_post.publish_change_to_clients!(:revised)
    end

    def say_hello
      raw =
        I18n.t(
          "#{I18N_KEY}.hello.message",
          i18n_post_args(username: @user.username, title: SiteSetting.title),
        )

      raw = <<~MD
      #{raw}

      #{instance_eval(&@next_instructions)}
      MD

      title = I18n.t("#{I18N_KEY}.hello.title", title: SiteSetting.title)
      title = title.gsub(/:([\w\-+]+(?::t\d)?):/, "").strip if SiteSetting.max_emojis_in_title == 0

      opts = {
        title: title,
        target_usernames: @user.username,
        archetype: Archetype.private_message,
        subtype: TopicSubtype.system_message,
      }

      if @post && @post.topic.private_message? &&
           @post.topic.topic_allowed_users.pluck(:user_id).include?(@user.id)
        opts = opts.merge(topic_id: @post.topic_id)
      end

      if @data[:topic_id]
        opts = opts.merge(topic_id: @data[:topic_id]).except(:title, :target_usernames, :archetype)
      end

      post = reply_to(@post, raw, opts)
      @data[:topic_id] = post.topic.id
      @data[:track] = self.class.to_s
      post
    end

    def missing_bookmark
      return unless valid_topic?(@post.topic_id)
      return if @post.user_id == self.discobot_user.id

      fake_delay
      enqueue_timeout_job(@user)
      unless @data[:attempted]
        reply_to(@post, I18n.t("#{I18N_KEY}.bookmark.not_found", i18n_post_args))
      end
      false
    end

    def reply_to_bookmark
      return unless valid_topic?(@post.topic_id)
      return unless @post.user_id == self.discobot_user.id

      profile_page_url = url_helpers(:user_url, username: @user.username)
      bookmark_url = "#{profile_page_url}/activity/bookmarks"
      raw = <<~MD
        #{I18n.t("#{I18N_KEY}.bookmark.reply", i18n_post_args(bookmark_url: bookmark_url))}

        #{instance_eval(&@next_instructions)}
      MD

      fake_delay

      reply = reply_to(@post, raw)
      enqueue_timeout_job(@user)
      reply
    end

    def reply_to_onebox
      post_topic_id = @post.topic_id
      return unless valid_topic?(post_topic_id)

      @post.post_analyzer.cook(@post.raw, {})

      if @post.post_analyzer.found_oneboxes?
        raw = <<~MD
          #{I18n.t("#{I18N_KEY}.onebox.reply", i18n_post_args)}

          #{instance_eval(&@next_instructions)}
        MD

        fake_delay

        reply = reply_to(@post, raw)
        enqueue_timeout_job(@user)
        reply
      else
        fake_delay
        unless @data[:attempted]
          reply_to(@post, I18n.t("#{I18N_KEY}.onebox.not_found", i18n_post_args))
        end
        enqueue_timeout_job(@user)
        false
      end
    end

    def track_images_like
      post_topic_id = @post.topic_id
      return unless valid_topic?(post_topic_id)

      post_liked =
        PostAction.exists?(
          post_action_type_id: PostActionType.types[:like],
          post_id: @data[:last_post_id],
          user_id: @user.id,
        )

      if post_liked
        set_state_data(:liked, true)

        if (post_id = get_state_data(:post_id)) && (post = Post.find_by(id: post_id))
          fake_delay
          like_post(post)

          raw = <<~MD
            #{I18n.t("#{I18N_KEY}.images.reply", i18n_post_args)}

            #{instance_eval(&@next_instructions)}
          MD

          reply = reply_to(@post, raw)
          enqueue_timeout_job(@user)
          return reply
        end
      end

      false
    end

    def reply_to_image
      post_topic_id = @post.topic_id
      return unless valid_topic?(post_topic_id)

      transition = true
      attempted_count = get_state_data(:attempted) || 0

      if attempted_count < 2
        @data[:skip_attempted] = true
        @data[:attempted] = false
      else
        @data[:skip_attempted] = false
      end

      cooked = @post.post_analyzer.cook(@post.raw, {})

      if Nokogiri::HTML5.fragment(cooked).css("img").size > 0
        set_state_data(:post_id, @post.id)

        if get_state_data(:liked)
          raw = <<~MD
            #{I18n.t("#{I18N_KEY}.images.reply", i18n_post_args)}

            #{instance_eval(&@next_instructions)}
          MD

          like_post(@post)
        else
          raw =
            I18n.t(
              "#{I18N_KEY}.images.like_not_found",
              i18n_post_args(url: Post.find_by(id: @data[:last_post_id]).url),
            )

          transition = false
        end
      else
        raw =
          I18n.t(
            "#{I18N_KEY}.images.not_found",
            i18n_post_args(
              image_url:
                "#{Discourse.base_url}/plugins/discourse-narrative-bot/images/dog-walk.gif",
            ),
          )

        transition = false
      end

      fake_delay

      set_state_data(:attempted, attempted_count + 1) if !transition
      reply = reply_to(@post, raw) unless @data[:attempted] && !transition
      enqueue_timeout_job(@user)
      transition ? reply : false
    end

    def missing_likes_like
      return unless valid_topic?(@post.topic_id)
      return if @post.user_id == self.discobot_user.id

      fake_delay
      enqueue_timeout_job(@user)

      last_post = Post.find_by(id: @data[:last_post_id])
      reply_to(@post, I18n.t("#{I18N_KEY}.likes.not_found", i18n_post_args(url: last_post.url)))
      false
    end

    def reply_to_likes
      post_topic_id = @post.topic_id
      return unless valid_topic?(post_topic_id)

      post_liked =
        PostAction.exists?(
          post_action_type_id: PostActionType.types[:like],
          post_id: @data[:last_post_id],
          user_id: @user.id,
        )

      if post_liked
        raw = <<~MD
          #{I18n.t("#{I18N_KEY}.likes.reply", i18n_post_args)}

          #{instance_eval(&@next_instructions)}
        MD

        fake_delay

        reply = reply_to(@post, raw)
        enqueue_timeout_job(@user)
        return reply
      end

      false
    end

    def reply_to_formatting
      post_topic_id = @post.topic_id
      return unless valid_topic?(post_topic_id)

      if Nokogiri::HTML5
           .fragment(@post.cooked)
           .css("b", "strong", "em", "i", ".bbcode-i", ".bbcode-b")
           .size > 0
        raw = <<~MD
          #{I18n.t("#{I18N_KEY}.formatting.reply", i18n_post_args)}

          #{instance_eval(&@next_instructions)}
        MD

        fake_delay

        reply = reply_to(@post, raw)
        enqueue_timeout_job(@user)
        reply
      else
        fake_delay
        unless @data[:attempted]
          reply_to(@post, I18n.t("#{I18N_KEY}.formatting.not_found", i18n_post_args))
        end
        enqueue_timeout_job(@user)
        false
      end
    end

    def reply_to_quote
      post_topic_id = @post.topic_id
      return unless valid_topic?(post_topic_id)

      doc = Nokogiri::HTML5.fragment(@post.cooked)

      if doc.css(".quote").size > 0
        raw = <<~MD
          #{I18n.t("#{I18N_KEY}.quoting.reply", i18n_post_args)}

          #{instance_eval(&@next_instructions)}
        MD

        fake_delay

        reply = reply_to(@post, raw)
        enqueue_timeout_job(@user)
        reply
      else
        fake_delay
        unless @data[:attempted]
          reply_to(@post, I18n.t("#{I18N_KEY}.quoting.not_found", i18n_post_args))
        end
        enqueue_timeout_job(@user)
        false
      end
    end

    def reply_to_emoji
      post_topic_id = @post.topic_id
      return unless valid_topic?(post_topic_id)

      doc = Nokogiri::HTML5.fragment(@post.cooked)

      if doc.css(".emoji").size > 0
        raw = <<~MD
          #{I18n.t("#{I18N_KEY}.emoji.reply", i18n_post_args)}

          #{instance_eval(&@next_instructions)}
        MD

        fake_delay

        reply = reply_to(@post, raw)
        enqueue_timeout_job(@user)
        reply
      else
        fake_delay
        unless @data[:attempted]
          reply_to(@post, I18n.t("#{I18N_KEY}.emoji.not_found", i18n_post_args))
        end
        enqueue_timeout_job(@user)
        false
      end
    end

    def reply_to_mention
      post_topic_id = @post.topic_id
      return unless valid_topic?(post_topic_id)

      if bot_mentioned?(@post)
        raw = <<~MD
          #{I18n.t("#{I18N_KEY}.mention.reply", i18n_post_args)}

          #{instance_eval(&@next_instructions)}
        MD

        fake_delay

        reply = reply_to(@post, raw)
        enqueue_timeout_job(@user)
        reply
      else
        fake_delay

        unless @data[:attempted]
          reply_to(
            @post,
            I18n.t(
              "#{I18N_KEY}.mention.not_found",
              i18n_post_args(username: @user.username, discobot_username: self.discobot_username),
            ),
          )
        end

        enqueue_timeout_job(@user)
        false
      end
    end

    def missing_flag
      return unless valid_topic?(@post.topic_id)

      # Remove any incorrect flags so that they can try again
      if @post.user_id == -2
        @post
          .post_actions
          .where(user_id: @user.id)
          .where(
            "post_action_type_id IN (?)",
            (PostActionType.flag_types.values - [PostActionType.types[:inappropriate]]),
          )
          .destroy_all
      end

      fake_delay
      reply_to(@post, I18n.t("#{I18N_KEY}.flag.not_found", i18n_post_args)) unless @data[:attempted]
      false
    end

    def reply_to_flag
      post_topic_id = @post.topic_id
      return unless valid_topic?(post_topic_id)
      return unless @post.user.id == -2

      raw = <<~MD
        #{I18n.t("#{I18N_KEY}.flag.reply", i18n_post_args(group_url: Group.find(Group::AUTO_GROUPS[:staff]).full_url))}

        #{instance_eval(&@next_instructions)}
      MD

      fake_delay

      reply = reply_to(@post, raw)
      @post.post_actions.where(user_id: @user.id).destroy_all

      enqueue_timeout_job(@user)
      reply
    end

    def reply_to_search
      post_topic_id = @post.topic_id
      return unless valid_topic?(post_topic_id)

      if @post.raw.include?(NewUserNarrative.search_answer) ||
           @post.raw.include?(NewUserNarrative.search_answer_emoji)
        fake_delay
        reply_to(
          @post,
          I18n.t("#{I18N_KEY}.search.reply", i18n_post_args(search_url: url_helpers(:search_url))),
        )
      else
        fake_delay
        unless @data[:attempted]
          reply_to(@post, I18n.t("#{I18N_KEY}.search.not_found", i18n_post_args))
        end
        enqueue_timeout_job(@user)
        false
      end
    end

    def end_reply
      fake_delay

      reply_to(
        @post,
        I18n.t(
          "#{I18N_KEY}.end.message",
          i18n_post_args(
            username: @user.username,
            base_url: Discourse.base_url,
            certificate: certificate,
            discobot_username: self.discobot_username,
            advanced_trigger: AdvancedUserNarrative.reset_trigger,
          ),
        ),
        topic_id: @data[:topic_id],
      )
    end

    def like_post(post)
      PostActionCreator.like(self.discobot_user, post)
    end

    def welcome_topic
      Topic.find_by(slug: "welcome-to-discourse", archetype: Archetype.default) ||
        Topic.recent(1).first
    end

    def url_helpers(url, opts = {})
      Rails.application.routes.url_helpers.public_send(
        url,
        opts.merge(host: Discourse.base_url_no_prefix),
      )
    end
  end
end
