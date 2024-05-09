# frozen_string_literal: true

describe "CategoryCreatedEdited" do
  before { SiteSetting.discourse_automation_enabled = true }

  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::CATEGORY_CREATED_EDITED)
  end

  context "when editing/creating a post" do
    it "fires the trigger" do
      category = nil

      list = capture_contexts { category = Fabricate(:category) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("category_created_edited")
      expect(list[0]["action"].to_s).to eq("create")
    end

    context "when category is restricted" do
      let(:parent_category_id) { Category.first.id }
      before do
        automation.upsert_field!(
          "restricted_category",
          "category",
          { value: parent_category_id },
          target: "trigger",
        )
      end

      context "when category is allowed" do
        it "fires the trigger" do
          list = capture_contexts { Fabricate(:category, parent_category_id: parent_category_id) }

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("category_created_edited")
        end
      end

      context "when category is not allowed" do
        it "doesn’t fire the trigger" do
          list = capture_contexts { Fabricate(:category) }

          expect(list).to be_blank
        end
      end
    end
  end
end
