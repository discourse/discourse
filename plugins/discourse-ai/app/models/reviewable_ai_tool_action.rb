# frozen_string_literal: true

require_dependency "reviewable"

class ReviewableAiToolAction < Reviewable
  def created_new!
    super

    self.topic ||= target_post&.topic
    self.category_id ||= topic&.category_id
  end

  def target_post
    return @target_post if defined?(@target_post)

    post_id = target&.post_id
    @target_post = post_id ? Post.find_by(id: post_id) : nil
  end

  def build_actions(actions, guardian, args)
    return actions if !pending?
    return actions if !Reviewable.viewable_by(guardian.user).exists?(id: id)

    approve =
      actions.add_bundle(
        "#{id}-approve",
        icon: "check",
        label: "discourse_ai.reviewables.ai_tool_action.approve.title",
      )

    build_action(actions, :approve, icon: "check", bundle: approve)

    reject =
      actions.add_bundle(
        "#{id}-reject",
        icon: "xmark",
        label: "discourse_ai.reviewables.ai_tool_action.reject.title",
      )

    build_action(actions, :reject, icon: "xmark", bundle: reject)
  end

  def perform_approve(performed_by, args)
    ensure_inline_post_contains_approval!(args)
    ensure_performed_by_is_a_real_person!(performed_by)

    tool, tool_class, context = build_tool!
    context.user = performed_by if tool_class.attribute_to_approver?

    # Suppress automation re-triggers caused by the tool's side effects
    # (e.g. edit_tags → topic_tags_changed → automation fires again → loop).
    result =
      if defined?(DiscourseAutomation)
        DiscourseAutomation.suppress_triggers { tool.invoke }
      else
        tool.invoke
      end

    ensure_tool_succeeded!(result)

    create_result(:success, :approved)
  end

  def perform_reject(performed_by, args)
    ensure_inline_post_contains_approval!(args)
    ensure_performed_by_is_a_real_person!(performed_by)

    create_result(:success, :rejected)
  end

  private

  # Rebuilds the tool from the persisted action. Returns [tool, tool_class,
  # context]; the caller sets context.user for audit attribution as needed.
  def build_tool!
    tool_action = target
    if tool_action.blank?
      raise Discourse::InvalidAccess.new(
              I18n.t("discourse_ai.reviewables.ai_tool_action.target_missing"),
            )
    end

    tool_class =
      DiscourseAi::Agents::Agent.all_available_tools.find { |t| t.name == tool_action.tool_name }

    if tool_class.blank?
      raise Discourse::InvalidAccess.new(
              I18n.t(
                "discourse_ai.reviewables.ai_tool_action.tool_not_found",
                tool_name: tool_action.tool_name,
              ),
            )
    end

    bot_user = User.find_by(id: tool_action.bot_user_id)
    if bot_user.blank?
      raise Discourse::InvalidAccess.new(
              I18n.t("discourse_ai.reviewables.ai_tool_action.bot_user_missing"),
            )
    end

    context = DiscourseAi::Agents::BotContext.new(messages: [])
    context.reviewable_id = id

    tool =
      tool_class.new(
        tool_action.tool_parameters.symbolize_keys,
        bot_user: bot_user,
        llm: nil,
        context: context,
      )

    [tool, tool_class, context]
  end

  def ensure_inline_post_contains_approval!(args)
    inline_post_id = args[:post_id] || args["post_id"]
    return if inline_post_id.blank?

    approval_post =
      Post.find_by(
        id: inline_post_id,
        topic_id: topic_id,
        user_id: target&.bot_user_id,
        deleted_at: nil,
      )
    approval_marker = "data-ai-tool-approval-reviewable-id='#{id}'"

    if approval_post.blank? || !approval_post.raw.include?(approval_marker)
      raise Discourse::InvalidAccess.new(
              I18n.t("discourse_ai.reviewables.ai_tool_action.post_mismatch"),
            )
    end
  end

  def ensure_performed_by_is_a_real_person!(performed_by)
    if performed_by.blank? || performed_by.bot?
      raise Discourse::InvalidAccess.new(
              I18n.t("discourse_ai.reviewables.ai_tool_action.performer_not_human"),
            )
    end
  end

  # The replayed tool reports precondition/service failures as an error hash
  # (e.g. the approver lost permission, or the target was already actioned
  # between enqueue and approval). Surface the reason to the moderator and let
  # the surrounding transaction roll back so the reviewable stays pending,
  # instead of recording a phantom approval for an action that never ran.
  def ensure_tool_succeeded!(result)
    return unless result.is_a?(Hash) && result[:status].to_s == "error"

    error =
      result[:error].to_s.presence ||
        I18n.t("discourse_ai.reviewables.ai_tool_action.execution_error_unknown")

    raise Discourse::InvalidAccess.new(
            "ai_tool_action_execution_error",
            nil,
            custom_message: "discourse_ai.reviewables.ai_tool_action.execution_error",
            custom_message_params: {
              error: error,
            },
          )
  end

  def build_action(actions, id, icon:, bundle: nil)
    actions.add(id, bundle: bundle) do |action|
      action.icon = icon
      action.label = "discourse_ai.reviewables.ai_tool_action.#{id}.title"
    end
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  force_review            :boolean          default(FALSE), not null
#  latest_score            :datetime
#  payload                 :json
#  potential_spam          :boolean          default(FALSE), not null
#  potentially_illegal     :boolean          default(FALSE)
#  reject_reason           :text
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  score                   :float            default(0.0), not null
#  status                  :integer          default("pending"), not null
#  target_type             :string
#  type                    :string           not null
#  type_source             :string           default("unknown"), not null
#  version                 :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  category_id             :integer
#  created_by_id           :integer          not null
#  target_created_by_id    :integer
#  target_id               :integer
#  topic_id                :integer
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score,created_at)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
