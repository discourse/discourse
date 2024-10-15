# frozen_string_literal: true

class DiscoursePoll::Poll
  RANKED_CHOICE = "ranked_choice"
  MULTIPLE = "multiple"
  REGULAR = "regular"

  def self.vote(user, post_id, poll_name, options)
    poll_id = nil

    serialized_poll =
      DiscoursePoll::Poll.change_vote(user, post_id, poll_name) do |poll|
        poll_id = poll.id
        # remove options that aren't available in the poll
        available_options = poll.poll_options.map { |o| o.digest }.to_set

        if poll.ranked_choice?
          options = options.values.map { |hash| hash }
          options.select! { |o| available_options.include?(o[:digest]) }
        else
          options.select! { |o| available_options.include?(o) }
        end

        if options.empty?
          raise DiscoursePoll::Error.new I18n.t("poll.requires_at_least_1_valid_option")
        end

        new_option_ids =
          poll
            .poll_options
            .each_with_object([]) do |option, obj|
              if poll.ranked_choice?
                obj << option.id if options.any? { |o| o[:digest] == option.digest }
              else
                obj << option.id if options.include?(option.digest)
              end
            end

        self.validate_votes!(poll, new_option_ids)

        old_option_ids =
          poll
            .poll_options
            .each_with_object([]) do |option, obj|
              obj << option.id if option.poll_votes.where(user_id: user.id).exists?
            end

        if poll.ranked_choice?
          # for ranked choice, we need to remove all votes and re-create them as there is no way to update them due to lack of primary key.
          PollVote.where(poll: poll, user: user).delete_all
          creation_set = new_option_ids
        else
          # remove non-selected votes
          PollVote
            .where(poll: poll, user: user)
            .where.not(poll_option_id: new_option_ids)
            .delete_all
          creation_set = new_option_ids - old_option_ids
        end

        # create missing votes
        creation_set.each do |option_id|
          if poll.ranked_choice?
            option_digest = poll.poll_options.find(option_id).digest

            PollVote.create!(
              poll: poll,
              user: user,
              poll_option_id: option_id,
              rank: options.find { |o| o[:digest] == option_digest }[:rank],
            )
          else
            PollVote.create!(poll: poll, user: user, poll_option_id: option_id)
          end
        end
      end

    if serialized_poll[:type] == RANKED_CHOICE
      serialized_poll[:ranked_choice_outcome] = DiscoursePoll::RankedChoice.outcome(poll_id)
    else
      # Ensure consistency here as we do not have a unique index to limit the
      # number of votes per the poll's configuration.
      is_multiple = serialized_poll[:type] == MULTIPLE
      offset = is_multiple ? (serialized_poll[:max] || serialized_poll[:options].length) : 1

      params = { poll_id: poll_id, offset: offset, user_id: user.id }

      DB.query(<<~SQL, params)
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
    end

    serialized_poll[:options].each do |option|
      if serialized_poll[:type] == RANKED_CHOICE
        option.merge!(
          rank:
            PollVote
              .joins(:poll_option)
              .where(poll_options: { digest: option[:id] }, user_id: user.id, poll_id: poll_id)
              .limit(1)
              .pluck(:rank),
        )
      elsif serialized_poll[:type] == MULTIPLE
        option.merge!(
          chosen:
            PollVote
              .joins(:poll_option)
              .where(poll_options: { digest: option[:id] }, user_id: user.id, poll_id: poll_id)
              .exists?,
        )
      end
    end

    if serialized_poll[:type] == MULTIPLE
      serialized_poll[:options].each do |option|
        option.merge!(
          chosen:
            PollVote
              .joins(:poll_option)
              .where(poll_options: { digest: option[:id] }, user_id: user.id, poll_id: poll_id)
              .exists?,
        )
      end
    end

    [serialized_poll, options]
  end

  def self.remove_vote(user, post_id, poll_name)
    poll_id = nil

    serialized_poll =
      DiscoursePoll::Poll.change_vote(user, post_id, poll_name) do |poll|
        poll_id = poll.id
        PollVote.where(poll: poll, user: user).delete_all
      end

    if serialized_poll[:type] == RANKED_CHOICE
      serialized_poll[:ranked_choice_outcome] = DiscoursePoll::RankedChoice.outcome(poll_id)
    end

    serialized_poll
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
        if raise_errors
          raise DiscoursePoll::Error.new I18n.t("poll.topic_must_be_open_to_toggle_status")
        end
        return
      end

      # either staff member or OP
      unless post.user_id == user&.id || user&.staff?
        if raise_errors
          raise DiscoursePoll::Error.new I18n.t("poll.only_staff_or_op_can_toggle_status")
        end
        return
      end

      poll = Poll.find_by(post_id: post_id, name: poll_name)

      if !poll
        if raise_errors
          raise DiscoursePoll::Error.new I18n.t("poll.no_poll_with_this_name", name: poll_name)
        end
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
    preload_serialized_voters!([poll], opts)[poll.id]
  end

  def self.preload_serialized_voters!(polls, opts = {})
    # This method is used in order to avoid N+1s and preloads serialized voters
    # for multiple polls from a topic view. After the first call, the serialized
    # voters are cached in the Poll object and returned from there for future
    # calls.

    page = [1, (opts["page"] || 1).to_i].max
    limit = (opts["limit"] || 25).to_i.clamp(1, 50)
    offset = (page - 1) * limit

    params = {
      offset: offset,
      offset_plus_limit: offset + limit,
      option_digest: opts[:option_id].presence,
    }

    result = {}

    uncached_poll_ids = []
    polls.each do |p|
      if p.serialized_voters_cache&.key?(params)
        result[p.id] = p.serialized_voters_cache[params]
      else
        uncached_poll_ids << p.id
      end
    end

    return result if uncached_poll_ids.empty?

    where_clause = params[:option_digest] ? "AND po.digest = :option_digest" : ""
    query = <<~SQL.gsub("/* where */", where_clause)
      SELECT poll_id, digest, rank, user_id
        FROM (
          SELECT pv.poll_id
               , po.digest
               , CASE pv.rank WHEN 0 THEN 'Abstain' ELSE CAST(pv.rank AS text) END AS rank
               , pv.user_id
               , u.username
               , ROW_NUMBER() OVER (PARTITION BY pv.poll_option_id ORDER BY pv.created_at) AS row
          FROM poll_votes pv
          JOIN poll_options po ON pv.poll_id = po.poll_id AND pv.poll_option_id = po.id
          JOIN users u ON pv.user_id = u.id
          WHERE pv.poll_id IN (:poll_ids)
                /* where */
        ) v
        WHERE row BETWEEN :offset AND :offset_plus_limit
        ORDER BY digest, CASE WHEN rank = 'Abstain' THEN 1 ELSE CAST(rank AS integer) END, username
      SQL

    votes = DB.query(query, params.merge(poll_ids: uncached_poll_ids))

    users =
      User
        .where(id: votes.map(&:user_id).uniq)
        .map { |u| [u.id, UserNameSerializer.new(u).serializable_hash] }
        .to_h

    polls_by_id = polls.index_by(&:id)
    votes.each do |v|
      if polls_by_id[v.poll_id].number?
        result[v.poll_id] ||= []
        result[v.poll_id] << users[v.user_id]
      elsif polls_by_id[v.poll_id].ranked_choice?
        result[v.poll_id] ||= Hash.new { |h, k| h[k] = [] }
        result[v.poll_id][v.digest] << { rank: v.rank, user: users[v.user_id] }
      else
        result[v.poll_id] ||= Hash.new { |h, k| h[k] = [] }
        result[v.poll_id][v.digest] << users[v.user_id]
      end
    end

    polls.each do |p|
      p.serialized_voters_cache ||= {}
      p.serialized_voters_cache[params] = result[p.id]
    end

    result
  end

  def self.transform_for_user_field_override(custom_user_field)
    existing_field = UserField.find_by(name: custom_user_field)
    existing_field ? "user_field_#{existing_field.id}" : custom_user_field
  end

  def self.grouped_poll_results(user, post_id, poll_name, user_field_name)
    raise Discourse::InvalidParameters.new(:post_id) if !Post.where(id: post_id).exists?
    poll =
      Poll.includes(:poll_options, :poll_votes, post: :topic).find_by(
        post_id: post_id,
        name: poll_name,
      )
    raise Discourse::InvalidParameters.new(:poll_name) unless poll

    # user must be allowed to post in topic
    guardian = Guardian.new(user)
    if !guardian.can_create_post?(poll.post.topic)
      raise DiscoursePoll::Error.new I18n.t("poll.user_cant_post_in_topic")
    end

    if SiteSetting.poll_groupable_user_fields.split("|").exclude?(user_field_name)
      raise Discourse::InvalidParameters.new(:user_field_name)
    end

    poll_votes = poll.poll_votes

    poll_options = {}
    poll.poll_options.each do |option|
      poll_options[option.id.to_s] = { html: option.html, digest: option.digest }
    end

    user_ids = poll_votes.map(&:user_id).uniq
    user_fields =
      UserCustomField.where(
        user_id: user_ids,
        name: transform_for_user_field_override(user_field_name),
      )

    user_field_map = {}
    user_fields.each do |f|
      # Build hash, so we can quickly look up field values for each user.
      user_field_map[f.user_id] = f.value
    end

    votes_with_field =
      poll_votes.map do |vote|
        v = vote.attributes
        v[:field_value] = user_field_map[vote.user_id]
        v
      end

    chart_data = []
    votes_with_field
      .group_by { |vote| vote[:field_value] }
      .each do |field_answer, votes|
        grouped_selected_options = {}

        # Create all the options with 0 votes. This ensures all the charts will have the same order of options, and same colors per option.
        poll_options.each do |id, option|
          grouped_selected_options[id] = { digest: option[:digest], html: option[:html], votes: 0 }
        end

        # Now go back and update the vote counts. Using hashes so we dont have n^2
        votes
          .group_by { |v| v["poll_option_id"] }
          .each do |option_id, votes_for_option|
            grouped_selected_options[option_id.to_s][:votes] = votes_for_option.length
          end

        group_label = field_answer ? field_answer.titleize : I18n.t("poll.user_field.no_data")
        chart_data << { group: group_label, options: grouped_selected_options.values }
      end
    chart_data
  end

  def self.schedule_jobs(post)
    Poll
      .where(post: post)
      .find_each do |poll|
        job_args = { post_id: post.id, poll_name: poll.name }

        Jobs.cancel_scheduled_job(:close_poll, job_args)

        if poll.open? && poll.close_at && poll.close_at > Time.zone.now
          Jobs.enqueue_at(poll.close_at, :close_poll, job_args)
        end
      end
  end

  def self.create!(post_id, poll)
    close_at =
      begin
        Time.zone.parse(poll["close"] || "")
      rescue ArgumentError
      end

    created_poll =
      Poll.create!(
        post_id: post_id,
        name: poll["name"].presence || "poll",
        close_at: close_at,
        type: poll["type"].presence || REGULAR,
        status: poll["status"].presence || "open",
        visibility: poll["public"] == "true" ? "everyone" : "secret",
        title: poll["title"],
        results: poll["results"].presence || "always",
        min: poll["min"],
        max: poll["max"],
        step: poll["step"],
        chart_type: poll["charttype"] || "bar",
        groups: poll["groups"],
      )

    poll["options"].each do |option|
      PollOption.create!(
        poll: created_poll,
        digest: option["id"].presence,
        html: option["html"].presence&.strip,
      )
    end
  end

  def self.extract(raw, topic_id, user_id = nil)
    # Poll Post handlers get called very early in the post
    # creation process. `raw` could be nil here.
    return [] if raw.blank?

    # bail-out early if the post does not contain a poll
    return [] if !raw.include?("[/poll]")

    # TODO: we should fix the callback mess so that the cooked version is available
    # in the validators instead of cooking twice
    raw = raw.sub(%r{\[quote.+/quote\]}m, "")
    cooked = PrettyText.cook(raw, topic_id: topic_id, user_id: user_id)

    Nokogiri
      .HTML5(cooked)
      .css("div.poll")
      .map do |p|
        poll = { "options" => [], "name" => DiscoursePoll::DEFAULT_POLL_NAME }

        # attributes
        p.attributes.values.each do |attribute|
          if attribute.name.start_with?(DiscoursePoll::DATA_PREFIX)
            poll[attribute.name[DiscoursePoll::DATA_PREFIX.length..-1]] = CGI.escapeHTML(
              attribute.value || "",
            )
          end
        end

        # options
        p
          .css("li[#{DiscoursePoll::DATA_PREFIX}option-id]")
          .each do |o|
            option_id = o.attributes[DiscoursePoll::DATA_PREFIX + "option-id"].value.to_s
            poll["options"] << { "id" => option_id, "html" => o.inner_html.strip }
          end

        # title
        title_element = p.css(".poll-title").first
        poll["title"] = title_element.inner_html.strip if title_element

        poll
      end
  end

  def self.validate_votes!(poll, options)
    num_of_options = options.length

    if poll.multiple?
      if poll.min && (num_of_options < poll.min)
        raise DiscoursePoll::Error.new(I18n.t("poll.min_vote_per_user", count: poll.min))
      elsif poll.max && (num_of_options > poll.max)
        raise DiscoursePoll::Error.new(I18n.t("poll.max_vote_per_user", count: poll.max))
      end
    elsif poll.ranked_choice?
      if poll.poll_options.length != num_of_options
        raise DiscoursePoll::Error.new(
                I18n.t(
                  "poll.ranked_choice.vote_options_mismatch",
                  count: poll.options.length,
                  provided: num_of_options,
                ),
              )
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
      raise DiscoursePoll::Error.new I18n.t("poll.post_is_deleted") if post.nil? || post.trashed?

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

      unless poll
        raise DiscoursePoll::Error.new I18n.t("poll.no_poll_with_this_name", name: poll_name)
      end
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
