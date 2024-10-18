# frozen_string_literal: true

RSpec.describe Chat::UpsertDraft do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }

    let(:guardian) { Guardian.new(current_user) }
    let(:data) { nil }
    let(:channel_id) { channel_1.id }
    let(:thread_id) { nil }
    let(:params) do
      { guardian: guardian, channel_id: channel_id, thread_id: thread_id, data: data }
    end

    before do
      SiteSetting.chat_enabled = true
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
      channel_1.add(current_user)
    end

    context "when all steps pass" do
      it { is_expected.to run_successfully }

      it "creates draft if data provided and not existing draft" do
        params[:data] = MultiJson.dump(message: "a")

        expect { result }.to change { Chat::Draft.count }.by(1)
        expect(Chat::Draft.last.data).to eq(params[:data])
      end

      it "updates draft if data provided and existing draft" do
        params[:data] = MultiJson.dump(message: "a")

        described_class.call(**params)

        params[:data] = MultiJson.dump(message: "b")

        expect { result }.to_not change { Chat::Draft.count }
        expect(Chat::Draft.last.data).to eq(params[:data])
      end

      it "destroys draft if empty data provided and existing draft" do
        params[:data] = MultiJson.dump(message: "a")

        described_class.call(**params)

        params[:data] = ""

        expect { result }.to change { Chat::Draft.count }.by(-1)
      end

      it "destroys draft if no data provided and existing draft" do
        params[:data] = MultiJson.dump(message: "a")

        described_class.call(**params)

        params[:data] = nil

        expect { result }.to change { Chat::Draft.count }.by(-1)
      end
    end

    context "when user can’t chat" do
      before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff] }

      it { is_expected.to fail_a_policy(:can_upsert_draft) }
    end

    context "when user can’t access the channel" do
      fab!(:channel_1) { Fabricate(:private_category_channel) }

      it { is_expected.to fail_a_policy(:can_upsert_draft) }
    end

    context "when channel is not found" do
      let(:channel_id) { -999 }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end

    context "when thread is not found" do
      let(:thread_id) { -999 }

      it { is_expected.to fail_a_step(:check_thread_exists) }
    end
  end
end
