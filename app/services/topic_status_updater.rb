# frozen_string_literal: true

TopicStatusUpdater =
  Struct.new(:topic, :user) do
    def update!(status, enabled, opts = {})
      status = Status.new(status, enabled)

      @topic_timer = topic.public_topic_timer

      updated = nil
      Topic.transaction do
        updated = change(status, opts)
        if updated
          highest_post_number = topic.highest_post_number
          create_moderator_post_for(status, opts)
          update_read_state_for(
            status,
            highest_post_number,
            silent_tracking: opts[:silent_tracking],
          )
        end
      end

      updated
    end

    private

    def change(status, opts = {})
      result = true

      if status.pinned? || status.pinned_globally?
        topic.update_pinned(status.enabled?, status.pinned_globally?, opts[:until])
      elsif status.autoclosed?
        rc = Topic.where(id: topic.id, closed: !status.enabled?).update_all(closed: status.enabled?)
        topic.closed = status.enabled?
        result = false if rc == 0
      else
        rc =
          Topic.where(:id => topic.id, status.name => !status.enabled).update_all(
            status.name => status.enabled?,
          )

        topic.public_send("#{status.name}=", status.enabled?)
        result = false if rc == 0
      end

      DiscourseEvent.trigger(:topic_closed, topic) if status.manually_closing_topic?

      if status.visible? && status.disabled?
        UserProfile.remove_featured_topic_from_all_profiles(topic)
      end

      if status.visible? && result
        topic.update_category_topic_count_by(status.enabled? ? 1 : -1)
        UserStatCountUpdater.public_send(
          status.enabled? ? :increment! : :decrement!,
          topic.first_post,
        )
      end

      if status.visible?
        topic.update(
          visibility_reason_id: opts[:visibility_reason_id] || Topic.visibility_reasons[:unknown],
        )
      end

      if @topic_timer
        if status.manually_closing_topic? || status.closing_topic?
          topic.delete_topic_timer(TopicTimer.types[:close])
          topic.delete_topic_timer(TopicTimer.types[:silent_close])
        elsif status.manually_opening_topic? || status.opening_topic?
          topic.delete_topic_timer(TopicTimer.types[:open])
          topic.inherit_auto_close_from_category
        end
      end

      # remove featured topics if we close/archive/make them invisible. Previously we used
      # to run the whole featuring logic but that could be very slow and have concurrency
      # errors on large sites with many autocloses and topics being created.
      if (
           (status.enabled? && (status.autoclosed? || status.closed? || status.archived?)) ||
             (status.disabled? && status.visible?)
         )
        CategoryFeaturedTopic.where(topic_id: topic.id).delete_all
      end

      result
    end

    def create_moderator_post_for(status, opts)
      message = opts[:message]
      topic.add_moderator_post(user, message || message_for(status), options_for(status, opts))
      topic.reload
    end

    def update_read_state_for(status, old_highest_read, silent_tracking: false)
      if (status.autoclosed? && status.enabled?) || (status.closed? && silent_tracking)
        # let's pretend all the people that read up to the autoclose message
        # actually read the topic
        PostTiming.pretend_read(topic.id, old_highest_read, topic.highest_post_number)
      end

      if status.closed? && status.enabled?
        sql_query = <<-SQL
          SELECT DISTINCT post_timings.user_id
          FROM post_timings
          JOIN user_options ON user_options.user_id = post_timings.user_id
          WHERE post_timings.topic_id = :topic_id
            AND user_options.topics_unread_when_closed = 'f'
        SQL
        user_ids = DB.query_single(sql_query, topic_id: topic.id)

        if user_ids.present?
          PostTiming.pretend_read(topic.id, old_highest_read, topic.highest_post_number, user_ids)
        end
      end
    end

    def message_for(status)
      if status.autoclosed?
        locale_key = status.locale_key.dup
        locale_key << "_lastpost" if @topic_timer&.based_on_last_post
        message_for_autoclosed(locale_key)
      end
    end

    def message_for_autoclosed(locale_key)
      num_minutes =
        if @topic_timer&.based_on_last_post
          (@topic_timer.duration_minutes || 0).minutes.to_i
        elsif @topic_timer&.created_at
          Time.zone.now - @topic_timer.created_at
        else
          Time.zone.now - topic.created_at
        end

      # all of the results above are in seconds, this brings them
      # back to the actual minutes integer
      num_minutes = (num_minutes / 1.minute).round

      if num_minutes.minutes >= 2.days
        I18n.t("#{locale_key}_days", count: (num_minutes.minutes / 1.day).round)
      else
        num_hours = (num_minutes.minutes / 1.hour).round
        if num_hours >= 2
          I18n.t("#{locale_key}_hours", count: num_hours)
        else
          I18n.t("#{locale_key}_minutes", count: num_minutes)
        end
      end
    end

    def options_for(status, opts = {})
      {
        bump: status.opening_topic?,
        post_type: Post.types[:small_action],
        silent: opts[:silent],
        action_code: status.action_code,
      }
    end

    Status =
      Struct.new(:name, :enabled) do
        %w[pinned_globally pinned autoclosed closed visible archived].each do |status|
          define_method("#{status}?") { name == status }
        end

        def enabled?
          enabled
        end

        def disabled?
          !enabled?
        end

        def action_code
          "#{name}.#{enabled? ? "enabled" : "disabled"}"
        end

        def locale_key
          "topic_statuses.#{action_code.tr(".", "_")}"
        end

        def opening_topic?
          (closed? || autoclosed?) && disabled?
        end

        def closing_topic?
          (closed? || autoclosed?) && enabled?
        end

        def manually_closing_topic?
          closed? && enabled?
        end

        def manually_opening_topic?
          closed? && disabled?
        end
      end
  end
