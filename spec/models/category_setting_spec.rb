# frozen_string_literal: true

RSpec.describe CategorySetting do
  it { is_expected.to belong_to(:category) }

  it do
    is_expected.to validate_numericality_of(:num_auto_bump_daily)
      .only_integer
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  it do
    is_expected.to validate_numericality_of(:auto_bump_cooldown_days)
      .only_integer
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  describe "nested replies conversion state" do
    fab!(:category)

    it "clears the conversion custom field when nested replies are disabled" do
      category.category_setting.update!(nested_replies_default: true)
      category.mark_nested_replies_conversion_completed!

      expect { category.category_setting.update!(nested_replies_default: false) }.to change {
        category.reload.nested_replies_conversion_completed?
      }.from(true).to(false)

      expect(
        CategoryCustomField.exists?(
          category_id: category.id,
          name: NestedReplies::CONVERSION_COMPLETED_CUSTOM_FIELD,
        ),
      ).to eq(false)
    end

    it "keeps the conversion custom field when nested replies stay enabled" do
      category.category_setting.update!(nested_replies_default: true)
      category.mark_nested_replies_conversion_completed!

      expect { category.category_setting.update!(auto_bump_cooldown_days: 2) }.not_to change {
        category.reload.nested_replies_conversion_completed?
      }
    end
  end
end
