# frozen_string_literal: true

DiscourseAutomation::Scriptable::USER_GLOBAL_NOTICE = "user_global_notice"

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::USER_GLOBAL_NOTICE) do
  field :notice, component: :message, required: true, accepts_placeholders: true
  field :level,
        component: :choices,
        extra: {
          content:
            %w[success error warning info].map do |level|
              {
                id: level,
                name: "discourse_automation.scriptables.user_global_notice.levels.#{level}",
              }
            end,
        }

  version 1

  triggerables [:stalled_topic]

  placeholder :username

  script do |context, fields, automation|
    placeholders = {}.merge(context["placeholders"] || {})

    if context["kind"] == DiscourseAutomation::Triggerable::STALLED_TOPIC
      user = context["topic"].user
      placeholders["username"] = user.username
    end

    notice = utils.apply_placeholders(fields.dig("notice", "value") || "", placeholders)
    level = fields.dig("level", "value")

    begin
      DiscourseAutomation::UserGlobalNotice.upsert(
        {
          identifier: automation.id,
          notice: notice,
          user_id: user.id,
          level: level,
          created_at: Time.now,
          updated_at: Time.now,
        },
        unique_by: "idx_discourse_automation_user_global_notices",
      )
    rescue ActiveRecord::RecordNotUnique
      # do nothing
    end
  end

  on_reset do |automation|
    DiscourseAutomation::UserGlobalNotice.where(identifier: automation.id).destroy_all
  end
end
