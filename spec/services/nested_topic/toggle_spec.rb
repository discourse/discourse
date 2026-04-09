# frozen_string_literal: true

RSpec.describe NestedTopic::Toggle do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_inclusion_of(:enabled).in_array([true, false]) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:topic)

    let(:params) { { topic_id: topic.id, enabled: } }
    let(:dependencies) { { guardian: admin.guardian } }
    let(:enabled) { true }

    context "when contract is invalid" do
      let(:params) { { topic_id: nil, enabled: true } }

      it { is_expected.to fail_a_contract }
    end

    context "when enabled is nil" do
      let(:params) { { topic_id: topic.id, enabled: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when topic is not found" do
      let(:params) { { topic_id: 0, enabled: true } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when user is not staff" do
      fab!(:admin, :user)

      it { is_expected.to fail_a_policy(:staff_can_edit) }
    end

    context "when enabling nested view" do
      let(:enabled) { true }

      it { is_expected.to run_successfully }

      it "creates a nested topic record" do
        expect { result }.to change { NestedTopic.where(topic: topic).count }.from(0).to(1)
      end

      context "when nested topic already exists" do
        before { Fabricate(:nested_topic, topic: topic) }

        it { is_expected.to run_successfully }

        it "does not create a duplicate record" do
          expect { result }.not_to change { NestedTopic.count }
        end
      end
    end

    context "when disabling nested view" do
      let(:enabled) { false }

      before { Fabricate(:nested_topic, topic: topic) }

      it { is_expected.to run_successfully }

      it "destroys the nested topic record" do
        expect { result }.to change { NestedTopic.where(topic: topic).count }.from(1).to(0)
      end
    end

    context "when disabling nested view without existing record" do
      let(:enabled) { false }

      it { is_expected.to run_successfully }
    end
  end
end
