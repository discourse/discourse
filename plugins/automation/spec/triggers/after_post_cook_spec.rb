# frozen_string_literal: true

require_relative "../discourse_automation_helper"

describe DiscourseAutomation::Triggerable::AFTER_POST_COOK do
  before { SiteSetting.discourse_automation_enabled = true }

  fab!(:post) { Fabricate(:post) }
  let(:topic) { post.topic }

  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggerable::AFTER_POST_COOK)
  end

  context "when filtered to a tag" do
    let(:filtered_tag) { Fabricate(:tag) }

    before do
      automation.upsert_field!(
        "restricted_tags",
        "tags",
        { value: ["random", filtered_tag.name] },
        target: "trigger",
      )
      automation.reload
    end

    it "should not fire when tag is missing" do
      captured = capture_contexts { post.rebake! }

      expect(captured).to be_blank
    end

    it "should fire when tag is present" do
      topic.tags << filtered_tag
      topic.save!

      list = capture_contexts { post.rebake! }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggerable::AFTER_POST_COOK)
    end
  end
end
