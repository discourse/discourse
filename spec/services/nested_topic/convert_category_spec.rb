# frozen_string_literal: true

RSpec.describe NestedTopic::ConvertCategory do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:category_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:already_nested_topic) { Fabricate(:topic, category: category) }
    fab!(:other_category_topic, :topic)

    let(:params) { { category_id: category.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      SiteSetting.nested_replies_enabled = true
      category.category_setting.update!(nested_replies_default: true)
      Fabricate(:nested_topic, topic: already_nested_topic)
    end

    context "when the contract is invalid" do
      let(:params) { { category_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when the category is not found" do
      let(:params) { { category_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:category) }
    end

    context "when nested replies are disabled" do
      before { SiteSetting.nested_replies_enabled = false }

      it { is_expected.to fail_a_policy(:nested_replies_enabled) }
    end

    context "when the user cannot edit the category" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_a_policy(:can_edit_category) }
    end

    context "when the category does not use nested replies by default" do
      before { category.category_setting.update!(nested_replies_default: false) }

      it { is_expected.to fail_a_policy(:category_nested_replies_enabled) }
    end

    context "when converting existing topics" do
      it { is_expected.to run_successfully }

      it "creates nested topic records for topics in the category" do
        expect { result }.to change { NestedTopic.where(topic: topic).count }.from(0).to(1)

        expect(NestedTopic.where(topic: already_nested_topic).count).to eq(1)
        expect(NestedTopic.where(topic: other_category_topic).exists?).to eq(false)
        expect(result[:converted_topic_count]).to eq(1)
      end

      it "marks the category conversion as completed" do
        expect { result }.to change { category.reload.nested_replies_conversion_completed? }.from(
          false,
        ).to(true)
      end
    end
  end
end
