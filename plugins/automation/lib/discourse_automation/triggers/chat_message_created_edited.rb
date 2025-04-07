# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::CHAT_MESSAGE_CREATED_EDITED) do
  field :action_type,
        component: :choices,
        extra: {
          content: [
            {
              id: "created",
              name: "discourse_automation.triggerables.chat_message_created_edited.created",
            },
            {
              id: "edited",
              name: "discourse_automation.triggerables.chat_message_created_edited.edited",
            },
          ],
        }
  field :restricted_channels, component: :chat_channels
  field :restricted_groups, component: :groups

  placeholder :message_url
  placeholder :message_text
  placeholder :channel_name
  placeholder :channel_slug
end
