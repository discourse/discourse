# frozen_string_literal: true

module DiscoursePoll
  class PollsUpdater
    POLL_ATTRIBUTES = %w[close_at max min results status step type visibility title groups]

    def self.update(post, polls)
      ::Poll.transaction do
        has_changed = false
        edit_window = SiteSetting.poll_edit_window_mins

        deleted_poll_names, created_poll_names = compute_name_diffs(post, polls)

        delete_polls(post, deleted_poll_names) if deleted_poll_names.present?

        if created_poll_names.present?
          create_polls(post, polls.slice(*created_poll_names))
          has_changed = true
        end

        result = update_existing_polls(post, polls, edit_window)
        return if result == :abort
        has_changed ||= result

        update_post_custom_fields(post)
        publish_changes(post) if has_changed
      end
    end

    private

    def self.compute_name_diffs(post, polls)
      old_poll_names = ::Poll.where(post: post).pluck(:name)
      new_poll_names = polls.keys
      deleted_poll_names = old_poll_names - new_poll_names
      created_poll_names = new_poll_names - old_poll_names
      [deleted_poll_names, created_poll_names]
    end

    def self.delete_polls(post, names)
      ::Poll.where(post: post, name: names).destroy_all
    end

    def self.create_polls(post, polls_hash)
      polls_hash.each { |name, poll| Poll.create!(post.id, poll) }
    end

    def self.update_existing_polls(post, polls, edit_window)
      has_changed = false

      existing_polls_for(post).find_each do |old_poll|
        result = process_poll_update(post, old_poll, polls[old_poll.name], edit_window)
        return :abort if result == :abort
        has_changed ||= result
      end

      has_changed
    end

    def self.existing_polls_for(post)
      ::Poll.includes(:poll_votes, :poll_options).where(post: post)
    end

    def self.process_poll_update(post, old_poll, new_poll_hash, edit_window)
      new_options = new_poll_hash["options"]
      attributes = extract_poll_attributes(new_poll_hash, old_poll)
      dynamic_flag = compute_dynamic_flag(new_poll_hash, old_poll)
      candidate = ::Poll.new(attributes)

      return false unless is_different?(old_poll, candidate, new_options)

      if votes_present_and_restricted?(old_poll, dynamic_flag) &&
           edit_window_expired?(old_poll, edit_window)
        post.errors.add(:base, build_edit_window_error(candidate.name, edit_window))
        return :abort
      end

      apply_poll_attribute_updates(old_poll, candidate)
      update_poll_options(old_poll, new_options, dynamic_flag)

      true
    end

    def self.votes_present_and_restricted?(old_poll, dynamic_flag)
      old_poll.poll_votes.size > 0 && !dynamic_flag
    end

    def self.edit_window_expired?(old_poll, edit_window)
      edit_window > 0 && old_poll.created_at < edit_window.minutes.ago
    end

    def self.build_edit_window_error(poll_name, edit_window)
      if poll_name == DiscoursePoll::DEFAULT_POLL_NAME
        I18n.t("poll.edit_window_expired.cannot_edit_default_poll_with_votes", minutes: edit_window)
      else
        I18n.t(
          "poll.edit_window_expired.cannot_edit_named_poll_with_votes",
          minutes: edit_window,
          name: poll_name,
        )
      end
    end

    def self.apply_poll_attribute_updates(old_poll, candidate)
      POLL_ATTRIBUTES.each { |attr| old_poll.public_send("#{attr}=", candidate.public_send(attr)) }
      old_poll.save!
    end

    def self.update_poll_options(old_poll, new_options, dynamic_flag)
      if dynamic_flag
        dynamic_update_options(old_poll, new_options)
      else
        nondynamic_replace_options(old_poll, new_options)
      end
    end

    def self.extract_poll_attributes(new_poll, old_poll)
      attributes = new_poll.slice(*POLL_ATTRIBUTES)
      attributes["visibility"] = new_poll["public"] == "true" ? "everyone" : "secret"
      attributes["close_at"] = begin
        Time.zone.parse(new_poll["close"])
      rescue StandardError
        nil
      end
      attributes["status"] = old_poll["status"]
      attributes["groups"] = new_poll["groups"]
      attributes
    end

    def self.compute_dynamic_flag(new_poll, old_poll)
      dynamic_flag = new_poll["dynamic"].to_s == "true"
      was_dynamic_before = old_poll.respond_to?(:dynamic) ? old_poll.dynamic : false
      dynamic_flag = false if !was_dynamic_before && dynamic_flag && old_poll.persisted?
      dynamic_flag
    end

    def self.dynamic_update_options(old_poll, new_poll_options)
      old_options_by_digest = old_poll.poll_options.index_by(&:digest)
      new_option_digests = new_poll_options.map { |o| o["id"] }.to_set

      to_delete = old_options_by_digest.keys - new_option_digests.to_a
      ::PollOption.where(poll: old_poll, digest: to_delete).destroy_all if to_delete.present?

      new_poll_options.each do |option|
        next if old_options_by_digest.key?(option["id"])

        ::PollOption.create!(poll: old_poll, digest: option["id"], html: option["html"].strip)
      end
    end

    def self.nondynamic_replace_options(old_poll, new_poll_options)
      anonymous_votes = old_poll.poll_options.map { |pv| [pv.digest, pv.anonymous_votes] }.to_h

      ::PollOption.where(poll: old_poll).destroy_all

      new_poll_options.each do |option|
        ::PollOption.create!(
          poll: old_poll,
          digest: option["id"],
          html: option["html"].strip,
          anonymous_votes: anonymous_votes[option["id"]],
        )
      end
    end

    def self.update_post_custom_fields(post)
      if ::Poll.exists?(post: post)
        post.custom_fields[HAS_POLLS] = true
      else
        post.custom_fields.delete(HAS_POLLS)
      end

      post.save_custom_fields(true)
    end

    def self.publish_changes(post)
      polls = ::Poll.includes(poll_options: :poll_votes).where(post: post)
      polls =
        ActiveModel::ArraySerializer.new(
          polls,
          each_serializer: PollSerializer,
          root: false,
          scope: Guardian.new(nil),
        ).as_json
      post.publish_message!("/polls/#{post.topic_id}", post_id: post.id, polls: polls)
    end

    def self.is_different?(old_poll, new_poll, new_options)
      POLL_ATTRIBUTES.each do |attr|
        return true if old_poll.public_send(attr) != new_poll.public_send(attr)
      end

      sorted_old_options = old_poll.poll_options.map { |o| o.digest }.sort
      sorted_new_options = new_options.map { |o| o["id"] }.sort

      sorted_old_options != sorted_new_options
    end
  end
end
