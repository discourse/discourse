# frozen_string_literal: true

class DiscoursePoll::Poll
  def self.vote(user, post_id, poll_name, options)
    poll_id = nil

    serialized_poll = DiscoursePoll::Poll.change_vote(user, post_id, poll_name) do |poll|
      poll_id = poll.id
      # remove options that aren't available in the poll
      available_options = poll.poll_options.map { |o| o.digest }.to_set
      options.select! { |o| available_options.include?(o) }

      raise DiscoursePoll::Error.new I18n.t("poll.requires_at_least_1_valid_option") if options.empty?

      new_option_ids = poll.poll_options.each_with_object([]) do |option, obj|
        obj << option.id if options.include?(option.digest)
      end

      self.validate_votes!(poll, new_option_ids)

      old_option_ids = poll.poll_options.each_with_object([]) do |option, obj|
        if option.poll_votes.where(user_id: user.id).exists?
          obj << option.id
        end
      end

      # remove non-selected votes
      PollVote
        .where(poll: poll, user: user)
        .where.not(poll_option_id: new_option_ids)
        .delete_all

      # create missing votes
      (new_option_ids - old_option_ids).each do |option_id|
        PollVote.create!(poll: poll, user: user, poll_option_id: option_id)
      end
    end

    # Ensure consistency here as we do not have a unique index to limit the
    # number of votes per the poll's configuration.
    is_multiple = serialized_poll[:type] == "multiple"
    offset = is_multiple ? (serialized_poll[:max] || serialized_poll[:options].length) : 1

    DB.query(<<~SQL, poll_id: poll_id, user_id: user.id, offset: offset)
    DELETE FROM poll_votes
    USING (
      SELECT
        poll_id,
        user_id
      FROM poll_votes
      WHERE poll_id = :poll_id
      AND user_id = :user_id
      ORDER BY created_at DESC
      OFFSET :offset
    ) to_delete_poll_votes
    WHERE poll_votes.poll_id = to_delete_poll_votes.poll_id
    AND poll_votes.user_id = to_delete_poll_votes.user_id
    SQL

    [serialized_poll, options]
  end

  def self.remove_vote(user, post_id, poll_name)
    DiscoursePoll::Poll.change_vote(user, post_id, poll_name) do |poll|
      PollVote.where(poll: poll, user: user).delete_all
    end
  end

  def self.toggle_status(user, post_id, poll_name, status, raise_errors = true)
    Poll.transaction do
      post = Post.find_by(id: post_id)
      guardian = Guardian.new(user)

      # post must not be deleted
      if post.nil? || post.trashed?
        raise DiscoursePoll::Error.new I18n.t("poll.post_is_deleted") if raise_errors
        return
      end

      # topic must not be archived
      if post.topic&.archived
        raise DiscoursePoll::Error.new I18n.t("poll.topic_must_be_open_to_toggle_status") if raise_errors
        return
      end

      # either staff member or OP
      unless post.user_id == user&.id || user&.staff?
        raise DiscoursePoll::Error.new I18n.t("poll.only_staff_or_op_can_toggle_status") if raise_errors
        return
      end

      poll = Poll.find_by(post_id: post_id, name: poll_name)

      if !poll
        raise DiscoursePoll::Error.new I18n.t("poll.no_poll_with_this_name", name: poll_name) if raise_errors
        return
      end

      poll.status = status
      poll.save!

      serialized_poll = PollSerializer.new(poll, root: false, scope: guardian).as_json
      payload = { post_id: post_id, polls: [serialized_poll] }

      post.publish_message!("/polls/#{post.topic_id}", payload)

      serialized_poll
    end
  end

  def self.serialized_voters(poll, opts = {})
    limit = (opts["limit"] || 25).to_i
    limit = 0  if limit < 0
    limit = 50 if limit > 50

    page = (opts["page"] || 1).to_i
    page = 1 if page < 1

    offset = (page - 1) * limit

    option_digest = opts["option_id"].to_s

    if poll.number?
      user_ids = PollVote
        .where(poll: poll)
        .group(:user_id)
        .order("MIN(created_at)")
        .offset(offset)
        .limit(limit)
        .pluck(:user_id)

      result = User.where(id: user_ids).map { |u| UserNameSerializer.new(u).serializable_hash }
    elsif option_digest.present?
      poll_option = PollOption.find_by(poll: poll, digest: option_digest)

      raise Discourse::InvalidParameters.new(:option_id) unless poll_option

      user_ids = PollVote
        .where(poll: poll, poll_option: poll_option)
        .group(:user_id)
        .order("MIN(created_at)")
        .offset(offset)
        .limit(limit)
        .pluck(:user_id)

      user_hashes = User.where(id: user_ids).map { |u| UserNameSerializer.new(u).serializable_hash }

      result = { option_digest => user_hashes }
    else
      votes = DB.query <<~SQL
        SELECT digest, user_id
          FROM (
            SELECT digest
                  , user_id
                  , ROW_NUMBER() OVER (PARTITION BY poll_option_id ORDER BY pv.created_at) AS row
              FROM poll_votes pv
              JOIN poll_options po ON pv.poll_option_id = po.id
              WHERE pv.poll_id = #{poll.id}
                AND po.poll_id = #{poll.id}
          ) v
          WHERE row BETWEEN #{offset} AND #{offset + limit}
      SQL

      user_ids = votes.map(&:user_id).uniq

      user_hashes = User
        .where(id: user_ids)
        .map { |u| [u.id, UserNameSerializer.new(u).serializable_hash] }
        .to_h

      result = {}
      votes.each do |v|
        result[v.digest] ||= []
        result[v.digest] << user_hashes[v.user_id]
      end
    end

    result
  end

  def self.transform_for_user_field_override(custom_user_field)
    existing_field = UserField.find_by(name: custom_user_field)
    existing_field ? "user_field_#{existing_field.id}" : custom_user_field
  end

  def self.grouped_poll_results(user, post_id, poll_name, user_field_name)
    raise Discourse::InvalidParameters.new(:post_id) if !Post.where(id: post_id).exists?

    poll = Poll.includes(:poll_options).includes(:poll_votes).find_by(post_id: post_id, name: poll_name)
    raise Discourse::InvalidParameters.new(:poll_name) unless poll

    raise Discourse::InvalidParameters.new(:user_field_name) unless SiteSetting.poll_groupable_user_fields.split('|').include?(user_field_name)

    poll_votes = poll.poll_votes

    poll_options = {}
    poll.poll_options.each do |option|
      poll_options[option.id.to_s] = { html: option.html, digest: option.digest }
    end

    user_ids = poll_votes.map(&:user_id).uniq
    user_fields = UserCustomField.where(user_id: user_ids, name: transform_for_user_field_override(user_field_name))

    user_field_map = {}
    user_fields.each do |f|
      # Build hash, so we can quickly look up field values for each user.
      user_field_map[f.user_id] = f.value
    end

    votes_with_field = poll_votes.map do |vote|
      v = vote.attributes
      v[:field_value] = user_field_map[vote.user_id]
      v
    end

    chart_data = []
    votes_with_field.group_by { |vote| vote[:field_value] }.each do |field_answer, votes|
      grouped_selected_options = {}

      # Create all the options with 0 votes. This ensures all the charts will have the same order of options, and same colors per option.
      poll_options.each do |id, option|
        grouped_selected_options[id] = {
          digest: option[:digest],
          html: option[:html],
          votes: 0
        }
      end

      # Now go back and update the vote counts. Using hashes so we dont have n^2
      votes.group_by { |v| v["poll_option_id"] }.each do |option_id, votes_for_option|
        grouped_selected_options[option_id.to_s][:votes] = votes_for_option.length
      end

      group_label = field_answer ? field_answer.titleize : I18n.t("poll.user_field.no_data")
      chart_data << { group: group_label, options: grouped_selected_options.values }
    end
    chart_data
  end

  def self.schedule_jobs(post)
    Poll.where(post: post).find_each do |poll|
      job_args = {
        post_id: post.id,
        poll_name: poll.name
      }

      Jobs.cancel_scheduled_job(:close_poll, job_args)

      if poll.open? && poll.close_at && poll.close_at > Time.zone.now
        Jobs.enqueue_at(poll.close_at, :close_poll, job_args)
      end
    end
  end

  def self.create!(post_id, poll)
    close_at = begin
      Time.zone.parse(poll["close"] || '')
    rescue ArgumentError
    end

    created_poll = Poll.create!(
      post_id: post_id,
      name: poll["name"].presence || "poll",
      close_at: close_at,
      type: poll["type"].presence || "regular",
      status: poll["status"].presence || "open",
      visibility: poll["public"] == "true" ? "everyone" : "secret",
      title: poll["title"],
      results: poll["results"].presence || "always",
      min: poll["min"],
      max: poll["max"],
      step: poll["step"],
      chart_type: poll["charttype"] || "bar",
      groups: poll["groups"]
    )

    poll["options"].each do |option|
      PollOption.create!(
        poll: created_poll,
        digest: option["id"].presence,
        html: option["html"].presence&.strip
      )
    end
  end

  def self.extract(raw, topic_id, user_id = nil)
    # TODO: we should fix the callback mess so that the cooked version is available
    # in the validators instead of cooking twice
    cooked = PrettyText.cook(raw, topic_id: topic_id, user_id: user_id)

    Nokogiri::HTML5(cooked).css("div.poll").map do |p|
      poll = { "options" => [], "name" => DiscoursePoll::DEFAULT_POLL_NAME }

      # attributes
      p.attributes.values.each do |attribute|
        if attribute.name.start_with?(DiscoursePoll::DATA_PREFIX)
          poll[attribute.name[DiscoursePoll::DATA_PREFIX.length..-1]] = CGI.escapeHTML(attribute.value || "")
        end
      end

      # options
      p.css("li[#{DiscoursePoll::DATA_PREFIX}option-id]").each do |o|
        option_id = o.attributes[DiscoursePoll::DATA_PREFIX + "option-id"].value.to_s
        poll["options"] << { "id" => option_id, "html" => o.inner_html.strip }
      end

      # title
      title_element = p.css(".poll-title").first
      if title_element
        poll["title"] = title_element.inner_html.strip
      end

      poll
    end
  end

  def self.validate_votes!(poll, options)
    num_of_options = options.length

    if poll.multiple?
      if poll.min && (num_of_options < poll.min)
        raise DiscoursePoll::Error.new(I18n.t(
          "poll.min_vote_per_user",
          count: poll.min
        ))
      elsif poll.max && (num_of_options > poll.max)
        raise DiscoursePoll::Error.new(I18n.t(
          "poll.max_vote_per_user",
          count: poll.max
        ))
      end
    elsif num_of_options > 1
      raise DiscoursePoll::Error.new(I18n.t("poll.one_vote_per_user"))
    end
  end
  private_class_method :validate_votes!

  def self.change_vote(user, post_id, poll_name)
    Poll.transaction do
      post = Post.find_by(id: post_id)

      # post must not be deleted
      if post.nil? || post.trashed?
        raise DiscoursePoll::Error.new I18n.t("poll.post_is_deleted")
      end

      # topic must not be archived
      if post.topic&.archived
        raise DiscoursePoll::Error.new I18n.t("poll.topic_must_be_open_to_vote")
      end

      # user must be allowed to post in topic
      guardian = Guardian.new(user)
      if !guardian.can_create_post?(post.topic)
        raise DiscoursePoll::Error.new I18n.t("poll.user_cant_post_in_topic")
      end

      poll = Poll.includes(:poll_options).find_by(post_id: post_id, name: poll_name)

      raise DiscoursePoll::Error.new I18n.t("poll.no_poll_with_this_name", name: poll_name) unless poll
      raise DiscoursePoll::Error.new I18n.t("poll.poll_must_be_open_to_vote") if poll.is_closed?

      if poll.groups
        poll_groups = poll.groups.split(",").map(&:downcase)
        user_groups = user.groups.map { |g| g.name.downcase }
        if (poll_groups & user_groups).empty?
          raise DiscoursePoll::Error.new I18n.t("js.poll.results.groups.title", groups: poll.groups)
        end
      end

      yield(poll)

      poll.reload

      serialized_poll = PollSerializer.new(poll, root: false, scope: guardian).as_json
      payload = { post_id: post_id, polls: [serialized_poll] }

      post.publish_message!("/polls/#{post.topic_id}", payload)

      serialized_poll
    end
  end
end
