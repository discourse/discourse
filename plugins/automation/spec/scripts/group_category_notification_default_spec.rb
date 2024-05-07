# frozen_string_literal: true

describe "GroupCategoryNotificationDefault" do
  fab!(:category)
  fab!(:group)

  before { SiteSetting.discourse_automation_enabled = true }

  context "when using category_created_edited trigger" do
    fab!(:automation) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scripts::GROUP_CATEGORY_NOTIFICATION_DEFAULT,
        trigger: DiscourseAutomation::Triggers::CATEGORY_CREATED_EDITED,
      )
    end

    before do
      automation.upsert_field!(
        "restricted_category",
        "category",
        { value: category.id },
        target: "trigger",
      )
      automation.upsert_field!("group", "group", { value: group.id }, target: "script")
      automation.upsert_field!(
        "notification_level",
        "category_notification_level",
        { value: 4 },
        target: "script",
      )
    end

    context "when category is allowed" do
      it "creates a GroupCategoryNotificationDefault record" do
        subcategory = nil
        expect { subcategory = Fabricate(:category, parent_category_id: category.id) }.to change {
          GroupCategoryNotificationDefault.count
        }.by(1)

        record = GroupCategoryNotificationDefault.last
        expect(record.category_id).to eq(subcategory.id)
        expect(record.group_id).to eq(group.id)
        expect(record.notification_level).to eq(4)
      end

      it "updates category notification level for existing members" do
        automation.upsert_field!(
          "update_existing_members",
          "boolean",
          { value: true },
          target: "script",
        )
        user = Fabricate(:user)
        group.add(user)
        subcategory = nil

        expect { subcategory = Fabricate(:category, parent_category_id: category.id) }.to change {
          CategoryUser.count
        }.by(1)

        record = CategoryUser.last
        expect(record.category_id).to eq(subcategory.id)
        expect(record.user_id).to eq(user.id)
        expect(record.notification_level).to eq(4)
      end
    end
  end
end
