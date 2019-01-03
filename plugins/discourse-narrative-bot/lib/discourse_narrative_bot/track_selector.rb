module DiscourseNarrativeBot
  class TrackSelector
    include Actions

    GENERIC_REPLIES_COUNT_PREFIX = 'discourse-narrative-bot:track-selector-count:'.freeze
    PUBLIC_DISPLAY_BOT_HELP_KEY = 'discourse-narrative-bot:track-selector:display-bot-help'.freeze

    TRACKS = [
      NewUserNarrative,
      AdvancedUserNarrative
    ]

    TOPIC_ACTIONS = [
      :delete,
      :topic_notification_level_changed
    ].each(&:freeze)

    RESET_TRIGGER_EXACT_MATCH_LENGTH = 200

    def initialize(input, user, post_id:, topic_id: nil)
      @input = input
      @user = user
      @post_id = post_id
      @topic_id = topic_id
      @post = Post.find_by(id: post_id)
    end

    def select
      data = Store.get(@user.id)

      if @post && @post.post_type == Post.types[:regular] && !is_topic_action?
        is_reply = @input == :reply
        @is_pm_to_bot = pm_to_bot?(@post)

        return if is_reply && reset_track

        if data && (data[:topic_id] == @post.topic_id) && @is_pm_to_bot
          state = data[:state]
          klass = (data[:track] || NewUserNarrative.to_s).constantize

          if is_reply && like_user_post
            terminate_track(data)
          elsif state&.to_sym == :end && is_reply
            bot_commands(bot_mentioned?) || generic_replies(klass.reset_trigger)
          elsif is_reply
            previous_status = data[:attempted]
            current_status = klass.new.input(@input, @user, post: @post, skip: skip_track?)
            data = Store.get(@user.id)
            data[:attempted] = !current_status

            if previous_status && data[:attempted] == previous_status && !data[:skip_attempted]
              generic_replies(klass.reset_trigger, state)
            else
              $redis.del(generic_replies_key(@user))
            end

            Store.set(@user.id, data)
          else
            klass.new.input(@input, @user, post: @post, skip: skip_track?)
          end
        elsif is_reply && (@is_pm_to_bot || public_reply?)
          like_user_post
          bot_commands
        end
      elsif data && data.dig(:state)&.to_sym != :end && is_topic_action?
        klass = (data[:track] || NewUserNarrative.to_s).constantize
        klass.new.input(@input, @user, post: @post, topic_id: @topic_id)
      end
    end

    def self.reset_trigger
      I18n.t(i18n_key("reset_trigger"))
    end

    def self.skip_trigger
      I18n.t(i18n_key("skip_trigger"))
    end

    def self.help_trigger
      I18n.t(i18n_key("help_trigger"))
    end

    def self.quote_trigger
      I18n.t("discourse_narrative_bot.quote.trigger")
    end

    def self.dice_trigger
      I18n.t("discourse_narrative_bot.dice.trigger")
    end

    def self.magic_8_ball_trigger
      I18n.t("discourse_narrative_bot.magic_8_ball.trigger")
    end

    private

    def is_topic_action?
      @is_topic_action ||= TOPIC_ACTIONS.include?(@input)
    end

    def reset_track
      reset = false

      TRACKS.each do |klass|
        if selected_track(klass)
          klass.new.reset_bot(@user, @post)
          reset = true
          break
        end
      end

      reset
    end

    def selected_track(klass)
      post_raw = @post.raw
      trigger = "#{self.class.reset_trigger} #{klass.reset_trigger}"

      if post_raw.length < RESET_TRIGGER_EXACT_MATCH_LENGTH && @is_pm_to_bot
        post_raw.match(Regexp.new("\\b\\W\?#{trigger}\\W\?\\b", 'i'))
      else
        match_trigger?(trigger)
      end
    end

    def bot_commands(hint = true)
      raw =
        if match_data = match_trigger?("#{self.class.dice_trigger} (\\d+)d(\\d+)")
          DiscourseNarrativeBot::Dice.roll(match_data[1].to_i, match_data[2].to_i)
        elsif match_trigger?(self.class.quote_trigger)
          DiscourseNarrativeBot::QuoteGenerator.generate(@user)
        elsif match_trigger?(self.class.magic_8_ball_trigger)
          DiscourseNarrativeBot::Magic8Ball.generate_answer
        elsif match_trigger?(self.class.help_trigger)
          help_message
        elsif hint
          message = I18n.t(self.class.i18n_key('random_mention.reply'),
            discobot_username: self.discobot_user.username,
            help_trigger: self.class.help_trigger
          )

          if public_reply?
            key = "#{PUBLIC_DISPLAY_BOT_HELP_KEY}:#{@post.topic_id}"
            last_bot_help_post_number = $redis.get(key)

            if !last_bot_help_post_number ||
                (last_bot_help_post_number &&
                 @post.post_number - 10 > last_bot_help_post_number.to_i &&
                 (1.day.to_i - $redis.ttl(key)) > 6.hours.to_i)

              $redis.setex(key, 1.day.to_i, @post.post_number)
              message
            end
          else
            message
          end
        end

      if raw
        fake_delay
        reply_to(@post, raw, skip_validations: true)
      end
    end

    def help_message
      discobot_username = self.discobot_user.username

      message = I18n.t(
        self.class.i18n_key('random_mention.tracks'),
        discobot_username: discobot_username,
        reset_trigger: self.class.reset_trigger,
        default_track: NewUserNarrative.reset_trigger,
        tracks: [NewUserNarrative.reset_trigger, AdvancedUserNarrative.reset_trigger].join(', ')
      )

      message << "\n\n#{I18n.t(self.class.i18n_key('random_mention.bot_actions'),
        discobot_username: discobot_username,
        dice_trigger: self.class.dice_trigger,
        quote_trigger: self.class.quote_trigger,
        magic_8_ball_trigger: self.class.magic_8_ball_trigger
      )}"
    end

    def generic_replies_key(user)
      "#{GENERIC_REPLIES_COUNT_PREFIX}#{user.id}"
    end

    def generic_replies(track_reset_trigger, state = nil)
      reset_trigger = "#{self.class.reset_trigger} #{track_reset_trigger}"
      key = generic_replies_key(@user)
      count = ($redis.get(key) || $redis.setex(key, 900, 0)).to_i

      case count
      when 0
        raw = I18n.t(self.class.i18n_key('do_not_understand.first_response'))

        if state && state.to_sym != :end
          raw = "#{raw}\n\n#{I18n.t(self.class.i18n_key('do_not_understand.track_response'), reset_trigger: reset_trigger, skip_trigger: self.class.skip_trigger)}"
        end

        reply_to(@post, raw)
      when 1
        reply_to(@post, I18n.t(self.class.i18n_key('do_not_understand.second_response'),
                               base_path: Discourse.base_path,
                               reset_trigger: self.class.reset_trigger
        ))
      else
        # Stay out of the user's way
      end

      $redis.incr(key)
    end

    def self.i18n_key(key)
      "discourse_narrative_bot.track_selector.#{key}"
    end

    def skip_track?
      if @is_pm_to_bot
        post_raw = @post.raw
        post_raw.match(/((^@#{self.discobot_user.username} #{self.class.skip_trigger})|(^#{self.class.skip_trigger}$))/i)
      else
        false
      end
    end

    def match_trigger?(trigger)
      discobot_username = self.discobot_user.username
      regexp = Regexp.new("<a class=\"mention\".*>@#{discobot_username}</a> #{trigger}", 'i')
      match = @post.cooked.match(regexp)

      if @is_pm_to_bot
        match || @post.raw.strip.match(Regexp.new("^#{trigger}$", 'i'))
      else
        match
      end
    end

    def like_user_post
      if @post.raw.match(/thank/i)
        PostActionCreator.like(self.discobot_user, @post)
      end
    end

    def bot_mentioned?
      @bot_mentioned ||= PostAnalyzer.new(@post.raw, @post.topic_id).raw_mentions.include?(
        self.discobot_user.username_lower
      )
    end

    def public_reply?
      !SiteSetting.discourse_narrative_bot_disable_public_replies &&
        (reply_to_bot_post?(@post) || bot_mentioned?)
    end

    def terminate_track(data)
      Store.set(@user.id, data.merge!(track: nil, state: nil, topic_id: nil))
      cancel_timeout_job(@user)
    end
  end
end
