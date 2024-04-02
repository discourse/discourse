# frozen_string_literal: true

require Rails.root.join("db/migrate/20230910021213_update_category_setting_approval_values.rb")

RSpec.describe UpdateCategorySettingApprovalValues do
  describe "#up" do
    context "when require_topic_approval is null" do
      let(:category) do
        Fabricate(:category, category_setting_attributes: { require_topic_approval: nil })
      end

      it "backfills with false (new default)" do
        silence_stdout do
          expect { described_class.new.up }.to change {
            category.reload.require_topic_approval
          }.from(nil).to(false)
        end
      end
    end

    context "when the category has no category setting" do
      before do
        category.category_setting.destroy!
        CategoryCustomField.create!(
          category: category,
          name: "require_topic_approval",
          value: "true",
        )
      end

      let(:category) { Fabricate(:category) }

      it "backfills with the custom field value" do
        silence_stdout do
          expect { described_class.new.up }.to change { category.reload.category_setting }.from(
            nil,
          ).to(have_attributes(require_topic_approval: true))
        end
      end
    end

    context "when the category has a category setting and the custom field changed" do
      before do
        CategoryCustomField.create!(category: category, name: "require_topic_approval", value: true)
      end

      let(:category) do
        Fabricate(:category, category_setting_attributes: { require_topic_approval: false })
      end

      it "backfills with the custom field value" do
        silence_stdout do
          expect { described_class.new.up }.to change {
            category.category_setting.reload.require_topic_approval
          }.from(false).to(true)
        end
      end
    end
  end
end
