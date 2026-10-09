# frozen_string_literal: true
require "active_support/core_ext/digest/uuid"
class DsaModeration
  TERRITORIES = %w[
    AT
    BE
    BG
    CY
    CZ
    DE
    DK
    EE
    ES
    FI
    FR
    GR
    HR
    HU
    IE
    IS
    IT
    LI
    LT
    LU
    LV
    MT
    NL
    NO
    PL
    PT
    RO
    SE
    SI
    SK
  ].freeze
  private_constant :TERRITORIES

  def self.recorder_for(reviewable_id:, actor: nil, metadata: {}, action_name: nil)
    return unless SiteSetting.dsa_reporting_enabled
    return if metadata[:first_handling] == false

    reviewable_id = metadata[:reviewable_id] || reviewable_id
    return unless reviewable_id
    reviewable = metadata[:reviewable]
    reviewable = Reviewable.find_by(id: reviewable_id) unless reviewable&.id == reviewable_id
    previous = DsaStatementOfRecord.find_by(reviewable_id: reviewable_id) unless reviewable
    return unless reviewable || previous
    if reviewable && metadata[:first_handling].nil?
      return if reviewable.reviewable_histories.transitioned.limit(2).count > 1
      return if reviewable.pending? && reviewable.reviewable_histories.transitioned.exists?
    end

    recorder =
      new(
        reviewable: reviewable,
        actor: actor || User.find_by(id: metadata[:actor_id]),
        action_name: action_name || metadata[:action_name],
        decision_provenance: metadata[:decision_provenance],
      )
    recorder.restore_origin(previous) if previous
    recorder
  end
  private_class_method :recorder_for

  def self.record_user_history(history, metadata = {})
    recorder =
      recorder_for(
        reviewable_id: history.reviewable_id,
        actor: history.acting_user,
        metadata: metadata,
        action_name: UserHistory.actions.invert[history.action],
      )
    return unless recorder

    recorder.record_history(history)
    recorder.flush
  end

  def self.record_action(reviewable, result, actor, action_name, args)
    return unless result.success?
    recorder =
      recorder_for(
        reviewable_id: reviewable.id,
        actor: actor,
        action_name: action_name,
        metadata:
          args[:moderation] ||
            { reviewable: reviewable, decision_provenance: args[:decision_provenance] },
      )
    return unless recorder

    history = reviewable.reviewable_histories.transitioned.order(:id).last
    recorder.record_transition(history) if history
    recorder.flush
  end

  def self.record_removal(target, actor = nil, metadata = {})
    recorder =
      recorder_for(reviewable_id: metadata[:reviewable_id], actor: actor, metadata: metadata)
    return unless recorder

    recorder.record_restriction(
      target: target,
      restriction: {
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
      },
    )
    recorder.flush
  end

  def self.record_post_destroyed(post, options, actor)
    return unless post.trashed? && post.post_type == Post.types[:regular]
    recorder = recorder_for(reviewable_id: options[:reviewable_id], actor: actor, metadata: options)
    return unless recorder

    if post.is_first_post? && post.topic&.trashed?
      recorder.record_topic_posts(post.topic, "DECISION_VISIBILITY_CONTENT_REMOVED")
    else
      recorder.record_restriction(
        target: post,
        restriction: {
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        },
      )
    end
    recorder.flush
  end

  def self.record_post_hidden(post, metadata)
    return unless post.hidden?
    recorder = recorder_for(reviewable_id: metadata[:reviewable_id], metadata: metadata)
    return unless recorder

    recorder.record_restriction(
      target: post,
      restriction: {
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_DISABLED"],
      },
    )
    recorder.flush
  end

  def restore_origin(statement)
    @reviewable_id = statement.reviewable_id
    @source_type = statement.payload["source_type"]
    @automated_detection = statement.payload["automated_detection"] == "Yes"
  end

  def self.record_edit(post:, revisor:)
    return unless SiteSetting.dsa_reporting_enabled

    changes = revisor.post_revision&.modifications || revisor.post_changes.merge(revisor.topic_diff)
    edited =
      %w[raw title].any? { |field| changes[field] && changes[field].first != changes[field].last }
    restricted_category =
      changes["category_id"] &&
        access_restricted?(previous_category_id: changes["category_id"].first, topic: post.topic)
    return unless edited || restricted_category

    recorder =
      recorder_for(
        reviewable_id: revisor.opts[:reviewable_id],
        actor: revisor.editor,
        metadata: revisor.opts[:moderation] || {},
        action_name: :agree_and_edit,
      )
    return unless recorder
    if edited
      recorder.record_edit(
        post: post,
        original_cooked:
          changes.dig("cooked", 0) ||
            (changes["raw"] ? PrettyText.cook(changes["raw"].first) : post.cooked),
      )
    end
    if restricted_category
      recorder.record_topic_posts(post.topic, "DECISION_VISIBILITY_CONTENT_DISABLED")
    end
    recorder.flush
  end

  def self.record_moved_posts(
    destination_topic_id:,
    original_topic_id:,
    post_ids: [],
    copied: nil,
    moderation: {}
  )
    return if copied
    recorder = recorder_for(reviewable_id: moderation[:reviewable_id], metadata: moderation)
    return unless recorder

    destination = Topic.find_by(id: destination_topic_id)
    original = Topic.with_deleted.find_by(id: original_topic_id)
    unless destination && original &&
             access_restricted?(previous_category_id: original.category_id, topic: destination)
      return
    end

    Post
      .where(id: post_ids, topic_id: destination.id, post_type: Post.types[:regular])
      .find_each do |post|
        recorder.record_restriction(
          target: post,
          restriction: {
            "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_DISABLED"],
          },
        )
      end
    recorder.flush
  end

  def self.access_restricted?(previous_category_id:, topic:)
    destination = topic.category
    return false unless destination&.read_restricted?

    previous = Category.find_by(id: previous_category_id)
    !previous&.read_restricted? || (previous.secure_group_ids - destination.secure_group_ids).any?
  end
  private_class_method :access_restricted?

  def self.record_topic_status(topic:, status:, enabled:, metadata: {})
    recorder = recorder_for(reviewable_id: metadata[:reviewable_id], metadata: metadata)
    return unless recorder

    visibility =
      if status == "closed" && enabled
        "DECISION_VISIBILITY_CONTENT_INTERACTION_RESTRICTED"
      elsif status == "visible" && !enabled
        "DECISION_VISIBILITY_CONTENT_DEMOTED"
      end
    return unless visibility

    Post
      .where(topic_id: topic.id, post_type: Post.types[:regular])
      .find_each do |post|
        recorder.record_restriction(
          target: post,
          restriction: {
            "decision_visibility" => [visibility],
          },
        )
      end
    recorder.flush
  end

  def initialize(reviewable:, actor:, action_name:, decision_provenance: nil)
    @records = {}
    @reviewable = reviewable
    @reviewable_id = reviewable&.id
    @action_name = action_name.to_s
    @automated_decision =
      if decision_provenance.to_s == "automated"
        "AUTOMATED_DECISION_FULLY"
      elsif decision_provenance.to_s == "assisted" || reviewable&.type == "ReviewableAiToolAction"
        "AUTOMATED_DECISION_PARTIALLY"
      elsif decision_provenance.blank? && actor&.bot?
        "AUTOMATED_DECISION_FULLY"
      else
        "AUTOMATED_DECISION_NOT_AUTOMATED"
      end
    @content = reviewable ? content_snapshot : {}
    @avatar =
      Upload.find_by(id: reviewable&.payload&.dig("avatar_upload_id")) ||
        User.find_by(id: @content[:recipient_id])&.uploaded_avatar
    @recipient_id = @content[:recipient_id] || @reviewable&.target_created_by_id
    @source_type = detect_source_type if reviewable
    @automated_detection = automated_detection? if reviewable
  end

  attr_reader :content

  def flush
    groups =
      @records.values.group_by do |record|
        [record[:recipient_id], record[:payload]["content_date"]]
      end
    groups.each do |(recipient_id, content_date), items|
      payload =
        items
          .map { |item| item[:payload] }
          .reduce { |previous, incoming| merge_payloads(previous, incoming) }
      id =
        Digest::UUID.uuid_v5(
          Digest::UUID::DNS_NAMESPACE,
          "#{Discourse.current_hostname}:reviewable:#{@reviewable_id}:#{recipient_id}:#{content_date}:#{payload["application_date"]}:#{payload["automated_decision"]}",
        )
      payload["puid"] = id
      DsaStatementOfRecord.transaction do
        DsaStatementOfRecord.insert_all(
          [{ id: id, reviewable_id: @reviewable_id, payload: payload }],
          unique_by: :id,
        )
        statement = DsaStatementOfRecord.lock.find(id)
        statement.update!(payload: merge_payloads(statement.payload, payload))
      end
    end
    @records.clear
  end

  def record_history(history)
    action = UserHistory.actions.invert[history.action]
    case action
    when :delete_user
      return if User.exists?(history.target_user_id)
      record_account_restriction(
        user: User.new(id: history.target_user_id),
        restriction: {
          "decision_account" => "DECISION_ACCOUNT_TERMINATED",
        },
      )
    when :suspend_user, :silence_user
      user = User.find_by(id: history.target_user_id)
      return unless user
      restriction =
        (
          if action == :suspend_user
            { "decision_account" => "DECISION_ACCOUNT_SUSPENDED" }
          else
            { "decision_provision" => "DECISION_PROVISION_PARTIAL_SUSPENSION" }
          end
        )
      record_account_restriction(user: user, restriction: restriction)
    when :removed_avatar
      if @avatar
        record_restriction(
          target: @avatar,
          restriction: {
            "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
          },
        )
      end
    when :post_locked
      post = Post.find_by(id: history.post_id)
      if post
        record_restriction(
          target: post,
          restriction: {
            "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_INTERACTION_RESTRICTED"],
          },
        )
      end
    when :topic_slow_mode_set
      topic = Topic.find_by(id: history.topic_id)
      if topic && topic.slow_mode_seconds > 0
        record_topic_posts(topic, "DECISION_VISIBILITY_CONTENT_INTERACTION_RESTRICTED")
      end
    end
  end

  def record_transition(history)
    reviewable = history.reviewable
    if reviewable.is_a?(ReviewableQueuedPost) &&
         (history.rejected? || history.deleted? && history.created_by_id != @recipient_id)
      content =
        (
          if reviewable.id == @reviewable.id
            @content
          else
            self
              .class
              .new(reviewable: reviewable, actor: history.created_by, action_name: @action_name)
              .content
          end
        )
      record_snapshot(
        content: content,
        restriction: {
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_DISABLED"],
        },
      )
      return
    end
    target = target_snapshot(reviewable)
    retained =
      @action_name.in?(
        %w[
          agree_and_keep
          agree_and_keep_hidden
          agree_and_keep_deleted
          disagree_and_keep_deleted
          reject_and_keep_deleted
        ],
      )
    if retained && target
      if target.respond_to?(:deleted_at) && target.deleted_at ||
           target.respond_to?(:user_deleted?) && target.user_deleted?
        record_restriction(
          target: target,
          restriction: {
            "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
          },
        )
      elsif target.respond_to?(:hidden?) && target.hidden?
        record_restriction(
          target: target,
          restriction: {
            "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_DISABLED"],
          },
        )
      end
    end
    if @action_name.in?(%w[agree_and_hide hide_post]) && target.respond_to?(:hidden?) &&
         target.hidden?
      record_restriction(
        target: target,
        restriction: {
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_DISABLED"],
        },
      )
    end
  end

  def record_topic_posts(topic, visibility)
    Post
      .with_deleted
      .where(topic_id: topic.id, post_type: Post.types[:regular])
      .where("deleted_at IS NULL OR post_number = 1")
      .find_each do |post|
        record_restriction(target: post, restriction: { "decision_visibility" => [visibility] })
      end
  end

  def record_restriction(target:, restriction:)
    content =
      (
        if target.class.name == @content[:target_type] && target.id == @content[:target_id]
          @content
        else
          describe_content(target)
        end
      )
    record_snapshot(content: content, restriction: restriction)
  end

  def record_edit(post:, original_cooked:)
    content = describe_content(post).merge(content_type: media_types(original_cooked))
    content[:content_type_other] = "Embedded content" if content[:content_type].include?(
      "CONTENT_TYPE_OTHER",
    )
    record_snapshot(
      content: content,
      restriction: {
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
      },
    )
  end

  def record_account_restriction(user:, restriction:)
    restriction = restriction.dup
    if restriction["decision_account"] == "DECISION_ACCOUNT_SUSPENDED" && user.suspended_till
      restriction["end_date_account_restriction"] = user.suspended_till.to_date.iso8601
    elsif restriction["decision_provision"] && user.silenced_till
      restriction["end_date_service_restriction"] = user.silenced_till.to_date.iso8601
    end
    content =
      user.id == @recipient_id && @content[:content_date] ? @content : describe_content(user)
    record_snapshot(
      content: content.merge(target_type: "User", target_id: user.id, recipient_id: user.id),
      restriction: restriction,
    )
  end

  private

  def content_snapshot
    target = target_snapshot
    if @reviewable.is_a?(ReviewableQueuedPost) && target.nil?
      return(
        {
          target_type: "ReviewableQueuedPost",
          target_id: @reviewable.id,
          content_date: @reviewable.created_at&.to_date&.iso8601,
          content_type: media_types(PrettyText.cook(@reviewable.payload["raw"].to_s)),
          content_type_other: "Embedded content",
          recipient_id: @reviewable.target_created_by_id,
        }
      )
    end
    describe_content(target)
  end

  def target_snapshot(reviewable = @reviewable)
    return unless reviewable&.target_type
    return reviewable.target if reviewable.target
    target_class = reviewable.class.polymorphic_class_for(reviewable.target_type)
    target_class.unscoped.find_by(id: reviewable.target_id)
  end

  def describe_content(target)
    cooked = target.respond_to?(:cooked) ? target.cooked : nil
    if target.is_a?(Post) && target.user_deleted?
      modifications = target.revisions.last&.modifications
      original_raw = modifications&.dig("raw", 0)
      cooked = modifications&.dig("cooked", 0) || PrettyText.cook(original_raw) if original_raw
    end
    result = {
      target_type: target&.class&.name || @reviewable&.target_type || @reviewable&.type,
      target_id: target&.id || @reviewable&.target_id || @reviewable_id,
      content_date: target&.created_at&.to_date&.iso8601,
      recipient_id:
        target.respond_to?(:user_id) ? target.user_id : @reviewable&.target_created_by_id,
    }
    if target.is_a?(User)
      result[:recipient_id] = target.id
      result[:content_type] = ["CONTENT_TYPE_OTHER"]
      result[:content_type_other] = "User account registration"
    elsif target.is_a?(Upload)
      result[:content_type] = ["CONTENT_TYPE_IMAGE"]
    elsif target&.class&.name == "Voice::Session"
      result[:content_date] = target.joined_at&.to_date&.iso8601
      result[:content_type] = ["CONTENT_TYPE_AUDIO"]
    elsif target.respond_to?(:cooked)
      result[:content_type] = media_types(cooked.to_s)
      result[:content_type_other] = "Embedded content" if result[:content_type].include?(
        "CONTENT_TYPE_OTHER",
      )
    else
      result[:content_type] = ["CONTENT_TYPE_OTHER"]
      result[:content_type_other] = "Content submitted for moderation"
    end
    result
  end

  def media_types(cooked)
    document = Nokogiri::HTML5.fragment(cooked)
    types = []
    types << "CONTENT_TYPE_TEXT" if document.text.strip.present?
    types << "CONTENT_TYPE_IMAGE" if document.css("img").present?
    types << "CONTENT_TYPE_AUDIO" if document.css("audio").present?
    types << "CONTENT_TYPE_VIDEO" if document.css("video").present?
    types << "CONTENT_TYPE_OTHER" if document.css("iframe, object, embed").present?
    types.presence || ["CONTENT_TYPE_TEXT"]
  end

  def record_snapshot(content:, restriction:)
    key = [content[:target_type], content[:target_id]]
    statement = @records[key]
    if statement
      payload = statement[:payload].merge(restriction)
      if restriction["decision_visibility"]
        payload["decision_visibility"] = (
          statement[:payload].fetch("decision_visibility", []) + restriction["decision_visibility"]
        ).uniq
      end
      statement[:payload] = payload
      return
    end

    payload =
      restriction.merge(
        "content_type" => content[:content_type],
        "content_date" => content[:content_date],
        "application_date" => Time.zone.today.iso8601,
        "territorial_scope" => TERRITORIES,
        "source_type" => @source_type,
        "automated_detection" => @automated_detection ? "Yes" : "No",
        "automated_decision" => @automated_decision,
      )
    if content[:content_type].include?("CONTENT_TYPE_OTHER")
      payload["content_type_other"] = content[:content_type_other]
    end
    @records[key] = {
      target_type: content[:target_type],
      target_id: content[:target_id],
      reviewable_id: @reviewable_id,
      recipient_id: content[:recipient_id] || @recipient_id,
      payload: payload,
    }
  end

  def detect_source_type
    member_ids = @reviewable.reviewable_scores.map(&:user_id)
    if User.where(id: member_ids, admin: false, moderator: false).where("id > 0").exists?
      "SOURCE_TYPE_OTHER_NOTIFICATION"
    else
      "SOURCE_VOLUNTARY"
    end
  end

  def automated_detection?
    @reviewable.type.in?(%w[ReviewableAiPost ReviewableAiChatMessage]) ||
      @reviewable.reviewable_scores.any? do |score|
        next false unless score.user_id == Discourse::SYSTEM_USER_ID
        score.reviewable_score_type != ReviewableScore.types[:needs_approval] ||
          score.reason.in?(%w[watched_word fast_typer auto_silence_regex suspect_user]) ||
          score.context.to_s.start_with?("discourse_ai")
      end
  end

  def merge_payloads(previous, incoming)
    merged = previous.merge(incoming)
    %w[content_type decision_visibility].each do |field|
      values = (previous.fetch(field, []) + incoming.fetch(field, [])).uniq
      merged[field] = values if values.present?
    end
    merged
  end
end
