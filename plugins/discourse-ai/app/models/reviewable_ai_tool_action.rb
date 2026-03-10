# frozen_string_literal: true

require_dependency "reviewable"

class ReviewableAiToolAction < Reviewable
  def build_actions(actions, guardian, args)
    return actions if !pending?

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

    tool =
      tool_class.new(
        tool_action.tool_parameters.symbolize_keys,
        bot_user: bot_user,
        llm: nil,
        context: DiscourseAi::Agents::BotContext.new(messages: []),
      )

    # Suppress automation re-triggers caused by the tool's side effects
    # (e.g. edit_tags → topic_tags_changed → automation fires again → loop).
    # Setting an active automation makes trigger!() return early.
    begin
      DiscourseAutomation.set_active_automation(id) if defined?(DiscourseAutomation)
      tool.invoke
    ensure
      DiscourseAutomation.set_active_automation(nil) if defined?(DiscourseAutomation)
    end

    create_result(:success, :approved)
  end

  def perform_reject(performed_by, args)
    create_result(:success, :rejected)
  end

  private

  def build_action(actions, id, icon:, bundle: nil)
    actions.add(id, bundle: bundle) do |action|
      action.icon = icon
      action.label = "discourse_ai.reviewables.ai_tool_action.#{id}.title"
    end
  end
end
