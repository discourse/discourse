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

      topic.title =~ /^#{I18n.t('poll.prefix')}/i
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
      # Get the user's current vote.
      vote = get_vote(user)
      vote = nil unless details.keys.include? vote

      new_details = details.dup
      new_details[vote] -= 1 if vote
      new_details[option] += 1

      ::PluginStore.set("poll", vote_key(user), option)
      set_details! new_details
    end

    def serialize(user)
      return nil if details.nil?
      {options: details, selected: get_vote(user)}
    end

    private
    def details_key
      "poll_options_#{@post.id}"
    end

    def vote_key(user)
      "poll_vote_#{@post.id}_#{user.id}"
    end
  end
end
