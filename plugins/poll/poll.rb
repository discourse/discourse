module ::PollPlugin

  class Poll
    def initialize(post)
      @post = post
    end

    def is_poll?
      if !@post.post_number.nil? and @post.post_number > 1
        # Not a new post, and also not the first post.
        return false
      end

      topic = @post.topic

      # Topic is not set in a couple of cases in the Discourse test suite.
      return false if topic.nil?

      if @post.post_number.nil? and topic.highest_post_number > 0
        # New post, but not the first post in the topic.
        return false
      end

      topic.title =~ /^(#{I18n.t('poll.prefix').strip}|#{I18n.t('poll.closed_prefix').strip})\s?:/i
    end

    def has_poll_details?
      if SiteSetting.allow_user_locale?
        # If we allow users to select their locale of choice we cannot detect polls
        # by the prefix, so we fall back to checking if the poll details is set in
        # places to make sure polls are still accessible by users using a different
        # locale than the one used by the topic creator.
        not self.details.nil?
      else
        self.is_poll?
      end
    end

    # Called during validation of poll posts. Discourse already restricts edits to
    # the OP and staff, we want to make sure that:
    #
    # * OP cannot edit options after 5 minutes.
    # * Staff can only edit options after 5 minutes, not add/remove.
    def ensure_can_be_edited!
      # Return if this is a new post or the options were not modified.
      return if @post.id.nil? || (options.sort == details.keys.sort)

      # First 5 minutes -- allow any modification.
      return unless @post.created_at < 5.minutes.ago

      if User.find(@post.last_editor_id).staff?
        # Allow editing options, but not adding or removing.
        if options.length != details.keys.length
          @post.errors.add(:poll_options, I18n.t('poll.cannot_add_or_remove_options'))
        end
      else
        # Regular user, tell them to contact a moderator.
        @post.errors.add(:poll_options, I18n.t('poll.cannot_have_modified_options'))
      end
    end

    def is_closed?
      @post.topic.closed? || @post.topic.archived? || (!SiteSetting.allow_user_locale? && (@post.topic.title =~ /^#{I18n.t('poll.closed_prefix')}/i) === 0)
    end

    def options
      cooked = PrettyText.cook(@post.raw, topic_id: @post.topic_id)
      parsed = Nokogiri::HTML(cooked)
      poll_list = parsed.css(".poll-ui ul").first || parsed.css("ul").first
      if poll_list
        poll_list.css("li").map {|x| x.children.to_s.strip }.uniq
      else
        []
      end
    end

    def update_options!
      return unless self.is_poll?
      return if details && details.keys.sort == options.sort

      if details.try(:length) == options.length

        # Assume only renaming, no reordering. Preserve votes.
        old_details = self.details
        old_options = old_details.keys
        new_details = {}
        new_options = self.options
        rename = {}

        0.upto(options.length-1) do |i|
          new_details[ new_options[i] ] = old_details[ old_options[i] ]

          if new_options[i] != old_options[i]
            rename[ old_options[i] ] = new_options[i]
          end
        end
        self.set_details! new_details

        # Update existing user votes.
        # Accessing PluginStoreRow directly isn't a very nice approach but there's
        # no way around it unfortunately.
        # TODO: Probably want to move this to a background job.
        PluginStoreRow.where(plugin_name: "poll", value: rename.keys).where('key LIKE ?', vote_key_prefix+"%").find_each do |row|
          # This could've been done more efficiently using `update_all` instead of
          # iterating over each individual vote, however this will be needed in the
          # future once we support multiple choice polls.
          row.value = rename[ row.value ]
          row.save
        end

      else

        # Options were added or removed.
        new_options = self.options
        new_details = self.details || {}
        new_details.each do |key, value|
          unless new_options.include? key
            new_details.delete(key)
          end
        end
        new_options.each do |key|
          new_details[key] ||= 0
        end
        self.set_details! new_details

      end
    end

    def details
      @details ||= ::PluginStore.get("poll", details_key)
    end

    def set_details!(new_details)
      ::PluginStore.set("poll", details_key, new_details)
      @details = new_details
    end

    def get_vote(user)
      user.nil? ? nil : ::PluginStore.get("poll", vote_key(user))
    end

    def set_vote!(user, option)
      return if is_closed?

      # Get the user's current vote.
      DistributedMutex.new(details_key).synchronize do
        vote = get_vote(user)
        vote = nil unless details.keys.include? vote

        new_details = details.dup
        new_details[vote] -= 1 if vote
        new_details[option] += 1

        ::PluginStore.set("poll", vote_key(user), option)
        set_details! new_details
      end
    end

    def serialize(user)
      return nil if details.nil?
      {options: details, selected: get_vote(user), closed: is_closed?}
    end

    private
    def details_key
      "poll_options_#{@post.id}"
    end

    def vote_key_prefix
      "poll_vote_#{@post.id}_"
    end

    def vote_key(user)
      "#{vote_key_prefix}#{user.id}"
    end
  end
end
