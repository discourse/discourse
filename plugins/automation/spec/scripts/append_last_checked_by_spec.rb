# frozen_string_literal: true

describe "AppendLastCheckedBy" do
  fab!(:post) { Fabricate(:post, raw: "this is a post with no edit") }
  fab!(:moderator)

  fab!(:automation) do
    Fabricate(:automation, script: DiscourseAutomation::Scripts::APPEND_LAST_CHECKED_BY)
  end

  def trigger_automation(post)
    cooked = automation.trigger!("post" => post, "cooked" => post.cooked)
    checked_at = post.updated_at + 1.hour
    date_time = checked_at.strftime("%Y-%m-%dT%H:%M:%SZ")
    [cooked, checked_at, date_time]
  end

  def text(key)
    I18n.t("discourse_automation.scriptables.append_last_checked_by.#{key}")
  end

  describe "#trigger!" do
    it "works for newly created post" do
      cooked, checked_at, date_time = trigger_automation(post)

      expect(cooked.include?("<blockquote class=\"discourse-automation\">")).to be_truthy
      expect(
        cooked.include?(
          "<details><summary>#{text("summary")}</summary>#{text("details")}<input type=\"button\" value=\"#{text("button_text")}\" class=\"btn btn-checked\"></details>",
        ),
      ).to be_truthy
    end

    it "works for checked post" do
      topic = post.topic
      topic.custom_fields[DiscourseAutomation::TOPIC_LAST_CHECKED_BY] = moderator.username
      topic.custom_fields[DiscourseAutomation::TOPIC_LAST_CHECKED_AT] = post.updated_at + 1.hour
      topic.save_custom_fields

      cooked, checked_at = trigger_automation(post)

      expect(
        cooked.include?(
          PrettyText.cook(
            I18n.t(
              "discourse_automation.scriptables.append_last_checked_by.text",
              username: moderator.username,
              date_time:
                "[date=#{checked_at.to_date} time=#{checked_at.strftime("%H:%M:%S")} timezone=UTC]",
            ),
          ),
        ),
      ).to be_truthy
    end
  end
end
