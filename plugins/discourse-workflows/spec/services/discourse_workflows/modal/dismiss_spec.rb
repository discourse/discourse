# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Modal::Dismiss do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:modal_id) }

    it "limits the modal identifier length" do
      is_expected.to validate_length_of(:modal_id).is_at_most(
        DiscourseWorkflows::Nodes::Modal::V1::MODAL_ID_MAX_LENGTH,
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)

    let(:dependencies) { { guardian: user.guardian } }
    let(:modal_id) { "abcd1234abcd1234" }
    let(:params) { { modal_id: } }

    context "when the modal id is valid" do
      it { is_expected.to run_successfully }

      it "tells every tab of the user to close their copies of the modal" do
        messages =
          MessageBus.track_publish(DiscourseWorkflows::Nodes::Modal::V1.user_channel(user.id)) do
            result
          end

        expect(messages.size).to eq(1)
        message = messages.first
        expect(message.user_ids).to eq([user.id])
        expect(message.data).to eq(type: "close_modal", modal_id: modal_id)
      end
    end

    context "when the modal id is blank" do
      let(:modal_id) { "" }

      it { is_expected.to fail_a_contract }
    end
  end
end
