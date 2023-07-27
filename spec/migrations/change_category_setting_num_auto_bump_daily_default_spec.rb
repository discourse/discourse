# frozen_string_literal: true

require Rails.root.join(
          "db/migrate/20230727015254_change_category_setting_num_auto_bump_daily_default.rb",
        )

RSpec.describe ChangeCategorySettingNumAutoBumpDailyDefault do
  describe "#up" do
    context "when num_auto_bump_daily_default is null" do
      let(:category) do
        Fabricate(:category, category_setting_attributes: { num_auto_bump_daily: nil })
      end

      it "backfills with 0 (new default)" do
        expect { described_class.new.up }.to change { category.reload.num_auto_bump_daily }.from(
          nil,
        ).to(0)
      end
    end

    context "when the category has no category setting" do
      before do
        category.category_setting.destroy!
        CategoryCustomField.create!(category: category, name: "num_auto_bump_daily", value: "1")
      end

      let(:category) { Fabricate(:category) }

      it "backfills with the custom field value" do
        expect { described_class.new.up }.to change { category.reload.category_setting }.from(
          nil,
        ).to(have_attributes(num_auto_bump_daily: 1))
      end
    end

    context "when the category has a category setting and the custom field changed" do
      before do
        CategoryCustomField.create!(category: category, name: "num_auto_bump_daily", value: 2)
      end

      let(:category) do
        Fabricate(:category, category_setting_attributes: { num_auto_bump_daily: 1 })
      end

      it "backfills with the custom field value" do
        expect { described_class.new.up }.to change {
          category.category_setting.reload.num_auto_bump_daily
        }.from(1).to(2)
      end
    end
  end
end
