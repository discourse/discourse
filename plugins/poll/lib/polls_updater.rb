# frozen_string_literal: true

module DiscoursePoll
  class PollsUpdater

    POLL_ATTRIBUTES ||= %w{close_at max min results status step type visibility}

    def self.update(post, polls)
      ::Poll.transaction do
        has_changed = false
        edit_window = SiteSetting.poll_edit_window_mins

        old_poll_names = ::Poll.where(post: post).pluck(:name)
        new_poll_names = polls.keys

        deleted_poll_names = old_poll_names - new_poll_names
        created_poll_names = new_poll_names - old_poll_names

        # delete polls
        if deleted_poll_names.present?
          ::Poll.where(post: post, name: deleted_poll_names).destroy_all
        end

        # create polls
        if created_poll_names.present?
          has_changed = true
          polls.slice(*created_poll_names).values.each do |poll|
            Poll.create!(post.id, poll)
          end
        end

        # update polls
        ::Poll.includes(:poll_votes, :poll_options).where(post: post).find_each do |old_poll|
          new_poll = polls[old_poll.name]
          new_poll_options = new_poll["options"]

          attributes = new_poll.slice(*POLL_ATTRIBUTES)
          attributes["visibility"] = new_poll["public"] == "true" ? "everyone" : "secret"
          attributes["close_at"] = Time.zone.parse(new_poll["close"]) rescue nil
          attributes["status"] = old_poll["status"]
          poll = ::Poll.new(attributes)

          if is_different?(old_poll, poll, new_poll_options)

            # only prevent changes when there's at least 1 vote
            if old_poll.poll_votes.size > 0
              # can't change after edit window (when enabled)
              if edit_window > 0 && old_poll.created_at < edit_window.minutes.ago
                error = poll.name == DiscoursePoll::DEFAULT_POLL_NAME ?
                  I18n.t("poll.edit_window_expired.cannot_edit_default_poll_with_votes", minutes: edit_window) :
                  I18n.t("poll.edit_window_expired.cannot_edit_named_poll_with_votes", minutes: edit_window, name: poll.name)

                post.errors.add(:base, error)
                return
              end
            end

            # update poll
            POLL_ATTRIBUTES.each do |attr|
              old_poll.send("#{attr}=", poll.send(attr))
            end
            old_poll.save!

            # keep track of anonymous votes
            anonymous_votes = old_poll.poll_options.map { |pv| [pv.digest, pv.anonymous_votes] }.to_h

            # destroy existing options & votes
            ::PollOption.where(poll: old_poll).destroy_all

            # create new options
            new_poll_options.each do |option|
              ::PollOption.create!(
                poll: old_poll,
                digest: option["id"],
                html: option["html"].strip,
                anonymous_votes: anonymous_votes[option["id"]],
              )
            end

            has_changed = true
          end
        end

        if ::Poll.exists?(post: post)
          post.custom_fields[HAS_POLLS] = true
        else
          post.custom_fields.delete(HAS_POLLS)
        end

        post.save_custom_fields(true)

        if has_changed
          polls = ::Poll.includes(poll_options: :poll_votes).where(post: post)
          polls = ActiveModel::ArraySerializer.new(polls, each_serializer: PollSerializer, root: false).as_json
          post.publish_message!("/polls/#{post.topic_id}", post_id: post.id, polls: polls)
        end
      end
    end

    private

    def self.is_different?(old_poll, new_poll, new_options)
      # an attribute was changed?
      POLL_ATTRIBUTES.each do |attr|
        return true if old_poll.send(attr) != new_poll.send(attr)
      end

      # an option was changed?
      return true if old_poll.poll_options.map { |o| o.digest }.sort != new_options.map { |o| o["id"] }.sort

      # it's the same!
      false
    end

  end
end
