# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::FLAG_CREATED) do
  flag_types =
    PostActionTypeView.new.notify_flag_types.map do |sym, id|
      { id: id, name: "discourse_automation.triggerables.flag_created.flag_types.#{sym}" }
    end

  field :flag_type, component: :choices, extra: { content: flag_types }
  field :categories, component: :categories
  field :tags, component: :tags

  placeholder :topic_url
  placeholder :topic_title
  placeholder :post_url
  placeholder :post_number
  placeholder :flagger_username
  placeholder :flagged_username
  placeholder :flag_type
  placeholder :category
  placeholder :tags
  placeholder :post_excerpt
end
