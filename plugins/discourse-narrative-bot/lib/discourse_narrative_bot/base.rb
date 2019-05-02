# frozen_string_literal: true

module DiscourseNarrativeBot
  class Base
    include Actions

    class InvalidTransitionError < StandardError; end

    def input(input, user, post: nil, topic_id: nil, skip: false)
      new_post = nil
      @post = post
      @topic_id = topic_id
      @skip = skip

      synchronize(user) do
        @user = user
        @data = get_data(user) || {}
        @state = (@data[:state] && @data[:state].to_sym) || :begin
        @input = input
        opts = {}

        begin
          opts = transition

          loop do
            next_state = opts[:next_state]

            break if next_state == :end

            next_opts = self.class::TRANSITION_TABLE.fetch(next_state)
            prerequisite = next_opts[:prerequisite]

            break if !prerequisite || instance_eval(&prerequisite)

            [:next_state, :next_instructions].each do |key|
              opts[key] = next_opts[key]
            end
          end
        rescue InvalidTransitionError
          # For given input, no transition for current state
          return
        end

        next_state = opts[:next_state]
        action = opts[:action]

        if next_instructions = opts[:next_instructions]
          @next_instructions = next_instructions
        end

        begin
          old_data = @data.dup

          new_post =
            if (@skip && @state != :end)
              skip_tutorial(next_state)
            else
              self.send(action)
            end

          if new_post
            old_state = old_data[:state]
            state_changed = (old_state.to_s != next_state.to_s)
            clean_up_state(old_state) if state_changed

            @state = @data[:state] = next_state
            @data[:last_post_id] = new_post.id
            set_data(@user, @data)

            init_state(next_state) if state_changed

            if next_state == :end
              end_reply
              cancel_timeout_job(user)

              BadgeGranter.grant(
                Badge.find_by(name: self.class::BADGE_NAME),
                user
              )

              set_data(@user,
                topic_id: new_post.topic_id,
                state: :end,
                track: self.class.to_s
              )
            end
          end
        rescue => e
          @data = old_data
          set_data(@user, @data)
          raise e
        end
      end

      new_post
    end

    def reset_bot
      not_implemented
    end

    def set_data(user, value)
      DiscourseNarrativeBot::Store.set(user.id, value)
    end

    def get_data(user)
      DiscourseNarrativeBot::Store.get(user.id)
    end

    def notify_timeout(user)
      @data = get_data(user) || {}

      if post = Post.find_by(id: @data[:last_post_id])
        reply_to(post, I18n.t("discourse_narrative_bot.timeout.message",
          i18n_post_args(
            username: user.username,
            skip_trigger: TrackSelector.skip_trigger,
            reset_trigger: "#{TrackSelector.reset_trigger} #{self.class.reset_trigger}"
          )
        ), {}, skip_send_email: false)
      end
    end

    def certificate(type = nil)
      options = {
        user_id: @user.id,
        date: Time.zone.now.strftime('%b %d %Y'),
        format: :svg
      }
      options.merge!(type: type) if type

      src = Discourse.base_url + DiscourseNarrativeBot::Engine.routes.url_helpers.certificate_path(options)
      alt = CGI.escapeHTML(I18n.t("#{self.class::I18N_KEY}.certificate.alt"))

      "<img class='discobot-certificate' src='#{src}' width='650' height='464' alt='#{alt}'>"
    end

    protected

    def set_state_data(key, value)
      @data[@state] ||= {}
      @data[@state][key] = value
      set_data(@user, @data)
    end

    def get_state_data(key)
      @data[@state] ||= {}
      @data[@state][key]
    end

    def reset_data(user, additional_data = {})
      old_data = get_data(user)
      new_data = additional_data
      set_data(user, new_data)
      new_data
    end

    def transition
      options = self.class::TRANSITION_TABLE.fetch(@state).dup
      input_options = options.fetch(@input)
      options.merge!(input_options) unless @skip
      options
    rescue KeyError
      raise InvalidTransitionError.new
    end

    def skip_tutorial(next_state)
      return unless valid_topic?(@post.topic_id)

      fake_delay

      if next_state != :end
        reply = reply_to(@post, instance_eval(&@next_instructions))
        enqueue_timeout_job(@user)
        reply
      else
        @post
      end
    end

    def i18n_post_args(extra = {})
      { base_uri: Discourse.base_uri }.merge(extra)
    end

    def valid_topic?(topic_id)
      topic_id == @data[:topic_id]
    end

    def not_implemented
      raise 'Not implemented.'
    end

    private

    def clean_up_state(state)
      clean_up_method = "clean_up_#{state}"
      self.send(clean_up_method) if self.class.private_method_defined?(clean_up_method)
    end

    def init_state(state)
      init_method = "init_#{state}"
      self.send(init_method) if self.class.private_method_defined?(init_method)
    end
  end
end
