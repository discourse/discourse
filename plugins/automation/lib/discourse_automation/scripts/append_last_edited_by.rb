# frozen_string_literal: true

DiscourseAutomation::Scriptable::APPEND_LAST_EDITED_BY = "append_last_edited_by"

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::APPEND_LAST_EDITED_BY) do
  version 1

  triggerables [:after_post_cook]

  script do |context|
    post = context["post"]
    post_revision = post.revisions.where("user_id > 0").last
    username = post_revision&.user&.username || post.username
    updated_at = post_revision&.updated_at || post.updated_at

    cooked = context["cooked"]
    doc = Loofah.fragment(cooked)

    node = doc.css("blockquote.discourse-automation").first
    if node.blank?
      node = doc.document.create_element("blockquote")
      node["class"] = "discourse-automation"
      doc.add_child(node)
    end

    date_time =
      "[date=#{updated_at.to_date.to_s} time=#{updated_at.strftime("%H:%M:%S")} timezone=UTC]"
    node.inner_html +=
      PrettyText.cook(
        I18n.t(
          "discourse_automation.scriptables.append_last_edited_by.text",
          username: username,
          date_time: date_time,
        ),
      ).html_safe

    doc.try(:to_html)
  end
end
