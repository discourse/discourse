# frozen_string_literal: true
class DsaModeration
  class Context < ActiveSupport::CurrentAttributes
    attribute :recorder, :automated_decision
  end
  private_constant :Context

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

  def self.capture(reviewable:, actor:, action_name:)
    return yield unless SiteSetting.dsa_reporting_enabled
    return yield if Context.recorder

    recorder = new(reviewable: reviewable, actor: actor, action_name: action_name)
    Context.set(recorder: recorder) do
      before = recorder.snapshot
      result = yield
      recorder.record_changes(before: before) if !result.respond_to?(:success?) || result.success?
      result
    end
  end

  def self.capture_penalty(reviewable_id:, actor:, user:, action_name:)
    reviewable = Reviewable.find_by(id: reviewable_id) if SiteSetting.dsa_reporting_enabled &&
      reviewable_id
    return yield unless reviewable
    return yield if Context.recorder
    matches_user =
      reviewable.target_created_by_id == user.id ||
        reviewable.target_type == "User" && reviewable.target_id == user.id
    return yield unless matches_user

    ActiveRecord::Base.transaction do
      capture(reviewable: reviewable, actor: actor, action_name: action_name) { yield }
    end
  end

  def self.capture_edit(reviewable_id:, actor:, post:)
    return yield unless SiteSetting.dsa_reporting_enabled && reviewable_id

    reviewable =
      Reviewable.viewable_by(actor).find_by(id: reviewable_id, target: post, status: :pending)
    unless reviewable&.actions_for(actor.guardian)&.has?(:agree_and_edit)
      raise Discourse::InvalidAccess
    end

    ActiveRecord::Base.transaction do
      capture(reviewable: reviewable, actor: actor, action_name: :agree_and_edit) { yield }
    end
  end

  def self.with_automated_decision(&block)
    Context.set(automated_decision: true, &block)
  end

  def self.record_removal(target)
    return if target.is_a?(Topic)
    Context.recorder&.record_restriction(
      target: target,
      restriction: {
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
      },
    )
  end

  def self.record_edit(post:, changes:)
    unless %w[raw title].any? { |field|
             changes[field] && changes[field].first != changes[field].last
           }
      return
    end

    original_cooked =
      changes.dig("cooked", 0) ||
        (changes["raw"] ? PrettyText.cook(changes["raw"].first) : post.cooked)
    Context.recorder&.record_edit(post: post, original_cooked: original_cooked)
  end

  def self.record_topic_removal(topic)
    return unless Context.recorder
    return if topic.deleted_at.blank?

    Post
      .with_deleted
      .where(topic_id: topic.id, deleted_at: nil)
      .find_each { |post| record_removal(post) }
  end

  def self.record_topic_status(topic:, status:, enabled:)
    return unless Context.recorder

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
        Context.recorder.record_restriction(
          target: post,
          restriction: {
            "decision_visibility" => [visibility],
          },
        )
      end
  end

  def self.record_account_restriction(user:, restriction:)
    Context.recorder&.record_account_restriction(user: user, restriction: restriction)
  end

  def initialize(reviewable:, actor:, action_name:)
    @reviewable = reviewable
    @actor = actor
    @action_name = action_name.to_s
    @decision_key = SecureRandom.uuid
    @automated_decision =
      if Context.automated_decision || actor&.bot?
        "AUTOMATED_DECISION_FULLY"
      elsif reviewable.type == "ReviewableAiToolAction"
        "AUTOMATED_DECISION_PARTIALLY"
      else
        "AUTOMATED_DECISION_NOT_AUTOMATED"
      end
    @content = content_snapshot
    @recipient_id = @content[:recipient_id] || @reviewable.target_created_by_id
    @source_type = source_type
    @automated_detection = automated_detection?
  end

  def snapshot
    user = User.find_by(id: @recipient_id)
    target = target_snapshot
    {
      content: @content,
      deleted:
        target.respond_to?(:deleted_at) && target.deleted_at.present? ||
          target.respond_to?(:user_deleted?) && target.user_deleted?,
      hidden: target.respond_to?(:hidden?) && target.hidden?,
      raw: target.respond_to?(:raw) ? target.raw : nil,
      avatar: user&.uploaded_avatar,
      account_exists: user.present?,
      suspended_till: user&.suspended_till,
      silenced_till: user&.silenced_till,
      recent_posts:
        (
          if @action_name.include?("silence") && user
            Post.where(user: user, hidden: false).where("created_at > ?", 24.hours.ago).pluck(:id)
          else
            []
          end
        ),
    }
  end

  def record_changes(before:)
    after = snapshot
    visibility = []
    visibility << "DECISION_VISIBILITY_CONTENT_REMOVED" if after[:deleted] && !before[:deleted]
    visibility << "DECISION_VISIBILITY_CONTENT_DISABLED" if after[:hidden] && !before[:hidden]
    if before[:raw].present? && after[:raw].present? && before[:raw] != after[:raw]
      visibility << "DECISION_VISIBILITY_CONTENT_REMOVED"
    end
    if @action_name.in?(
         %w[
           agree_and_keep
           agree_and_keep_hidden
           agree_and_keep_deleted
           disagree_and_keep_deleted
           reject_and_keep_deleted
         ],
       )
      visibility << "DECISION_VISIBILITY_CONTENT_REMOVED" if after[:deleted]
      visibility << "DECISION_VISIBILITY_CONTENT_DISABLED" if after[:hidden] && !after[:deleted]
    end

    if @reviewable.is_a?(ReviewableQueuedPost) && @reviewable.rejected?
      visibility << "DECISION_VISIBILITY_CONTENT_DISABLED"
    end

    if visibility.present?
      record_snapshot(
        content: before[:content],
        restriction: {
          "decision_visibility" => visibility.uniq,
        },
      )
    end

    if before[:avatar] && !after[:avatar] && after[:account_exists]
      record_restriction(
        target: before[:avatar],
        restriction: {
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        },
      )
    end

    if before[:account_exists] && !after[:account_exists]
      record_account(restriction: { "decision_account" => "DECISION_ACCOUNT_TERMINATED" })
    elsif after[:suspended_till] && before[:suspended_till] != after[:suspended_till]
      record_account(restriction: { "decision_account" => "DECISION_ACCOUNT_SUSPENDED" })
    elsif after[:silenced_till] && before[:silenced_till] != after[:silenced_till]
      record_account(
        restriction: {
          "decision_provision" => "DECISION_PROVISION_PARTIAL_SUSPENSION",
        },
      )
    end

    Post
      .where(id: before[:recent_posts], hidden: true)
      .find_each do |post|
        record_restriction(
          target: post,
          restriction: {
            "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_DISABLED"],
          },
        )
      end

    if before[:deleted] && !after[:deleted] || before[:hidden] && !after[:hidden]
      reverse_restrictions(
        target_type: before[:content][:target_type],
        target_id: before[:content][:target_id],
      )
    end
    if before[:silenced_till] && !after[:silenced_till] ||
         before[:suspended_till] && !after[:suspended_till]
      reverse_restrictions(target_type: "User", target_id: @recipient_id)
    end
  end

  def record_restriction(target:, restriction:)
    record_snapshot(content: describe_content(target), restriction: restriction)
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
    content = user.id == @recipient_id ? @content : describe_content(user)
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

  def target_snapshot
    target_class = @reviewable.target_type&.safe_constantize
    return @reviewable.target unless target_class.respond_to?(:unscoped)

    target_class.unscoped.find_by(id: @reviewable.target_id)
  end

  def describe_content(target)
    result = {
      target_type: target&.class&.name || @reviewable.target_type || @reviewable.type,
      target_id: target&.id || @reviewable.target_id || @reviewable.id,
      content_date: target&.created_at&.to_date&.iso8601,
      recipient_id:
        target.respond_to?(:user_id) ? target.user_id : @reviewable.target_created_by_id,
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
      result[:content_type] = media_types(target.cooked.to_s)
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

  def record_account(restriction:)
    content = @content.merge(target_type: "User", target_id: @recipient_id)
    record_snapshot(content: content, restriction: restriction)
  end

  def record_snapshot(content:, restriction:)
    attributes = {
      decision_key: @decision_key,
      target_type: content[:target_type],
      target_id: content[:target_id],
    }
    statement = DsaStatementOfReason.find_or_initialize_by(attributes)
    payload = statement.payload.merge(restriction)
    payload["decision_visibility"] = (
      statement.payload.fetch("decision_visibility", []) +
        restriction.fetch("decision_visibility", [])
    ).uniq if restriction["decision_visibility"]
    if statement.new_record?
      puid = SecureRandom.uuid
      payload.merge!(
        "puid" => puid,
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
      statement.assign_attributes(
        puid: puid,
        reviewable_id: @reviewable.id,
        actor_id: @actor&.id,
        recipient_id: content[:recipient_id] || @recipient_id,
        action_name: @action_name,
      )
    end
    statement.payload = payload
    statement.save!
  end

  def source_type
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

  def reverse_restrictions(target_type:, target_id:)
    DsaStatementOfReason.where(
      reviewable_id: @reviewable.id,
      target_type: target_type,
      target_id: target_id,
      reversed_at: nil,
    ).find_each(&:reverse!)
  end
end
