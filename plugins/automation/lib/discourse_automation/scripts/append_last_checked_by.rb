# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::APPEND_LAST_CHECKED_BY) do
  version 1

  triggerables [:after_post_cook]

  script do |context|
    post = context["post"]
    topic = post.topic

    cooked = context["cooked"]
    doc = Loofah.fragment(cooked)
    node = doc.css("blockquote.discourse-automation").first

    if node.blank?
      node = doc.document.create_element("blockquote")
      node["class"] = "discourse-automation"
      doc.add_child(node)
    end

    username = topic.custom_fields[DiscourseAutomation::TOPIC_LAST_CHECKED_BY]
    checked_at = topic.custom_fields[DiscourseAutomation::TOPIC_LAST_CHECKED_AT]

    if username.present? && checked_at.present?
      checked_at = DateTime.parse(checked_at)

      date_time =
        "[date=#{checked_at.to_date} time=#{checked_at.strftime("%H:%M:%S")} timezone=UTC]"
      node.inner_html +=
        PrettyText.cook(
          I18n.t(
            "discourse_automation.scriptables.append_last_checked_by.text",
            username: username,
            date_time: date_time,
          ),
        ).html_safe
    end

    summary_tag =
      "<summary>#{I18n.t("discourse_automation.scriptables.append_last_checked_by.summary")}</summary>"
    button_tag =
      "<input type=\"button\" value=\"#{I18n.t("discourse_automation.scriptables.append_last_checked_by.button_text")}\" class=\"btn btn-checked\" />"
    node.inner_html +=
      "<details>#{summary_tag}#{I18n.t("discourse_automation.scriptables.append_last_checked_by.details")}#{button_tag}</details>"

    doc.try(:to_html)
  end
end
