# frozen_string_literal: true

describe DiscourseAutomation::Triggers::AFTER_POST_COOK do
  before { SiteSetting.discourse_automation_enabled = true }

  fab!(:post)
  let(:topic) { post.topic }
  let(:parent_category) { Fabricate(:category_with_definition) }
  let(:subcategory) { Fabricate(:category_with_definition, parent_category_id: parent_category.id) }

  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::AFTER_POST_COOK)
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
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::AFTER_POST_COOK)
    end
  end

  context "when filtered to a category" do
    context "when restricted to a subcategory" do
      before do
        automation.upsert_field!(
          "restricted_category",
          "category",
          { value: subcategory.id },
          target: "trigger",
        )
        topic.category = subcategory
        topic.save!
      end

      it "fires the trigger" do
        list = capture_contexts { post.rebake! }

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::AFTER_POST_COOK)
      end
    end

    context "when restricted to a parent category" do
      before do
        automation.upsert_field!(
          "restricted_category",
          "category",
          { value: parent_category.id },
          target: "trigger",
        )
        topic.category = subcategory
        topic.save!
      end

      it "fires the trigger for a subcategory" do
        list = capture_contexts { post.rebake! }

        expect(list.length).to eq(1)
      end
    end
  end
end
