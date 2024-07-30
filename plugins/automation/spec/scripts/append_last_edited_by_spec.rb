# frozen_string_literal: true

describe "AppendLastEditedBy" do
  fab!(:post) { Fabricate(:post, raw: "this is a post with no edit") }
  fab!(:moderator)

  fab!(:automation) do
    Fabricate(:automation, script: DiscourseAutomation::Scripts::APPEND_LAST_EDITED_BY)
  end

  def trigger_automation(post)
    cooked = automation.trigger!("post" => post, "cooked" => post.cooked)
    updated_at = post.updated_at
    date_time = updated_at.strftime("%Y-%m-%dT%H:%M:%SZ")
    [cooked, updated_at]
  end

  describe "#trigger!" do
    it "works for newly created post" do
      freeze_time

      cooked, updated_at = trigger_automation(post)
      expect(
        cooked.include?(
          PrettyText.cook(
            I18n.t(
              "discourse_automation.scriptables.append_last_edited_by.text",
              username: post.user.username,
              date_time:
                "[date=#{updated_at.to_date} time=#{updated_at.strftime("%H:%M:%S")} timezone=UTC]",
            ),
          ),
        ),
      ).to be_truthy
    end

    it "works for existing post with last edited by detail" do
      freeze_time

      cooked, updated_at = trigger_automation(post)
      expect(
        cooked.include?(
          PrettyText.cook(
            I18n.t(
              "discourse_automation.scriptables.append_last_edited_by.text",
              username: post.user.username,
              date_time:
                "[date=#{updated_at.to_date} time=#{updated_at.strftime("%H:%M:%S")} timezone=UTC]",
            ),
          ),
        ),
      ).to be_truthy

      PostRevisor.new(post).revise!(moderator, raw: "this is a post with edit")

      cooked, updated_at = trigger_automation(post.reload)
      expect(
        cooked.include?(
          PrettyText.cook(
            I18n.t(
              "discourse_automation.scriptables.append_last_edited_by.text",
              username: moderator.username,
              date_time:
                "[date=#{updated_at.to_date} time=#{updated_at.strftime("%H:%M:%S")} timezone=UTC]",
            ),
          ),
        ),
      ).to be_truthy
    end
  end
end
