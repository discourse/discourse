# frozen_string_literal: true

RSpec.describe Checklist::Toggle do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(post_id: 1, checkbox_offset: 0) }

    it { is_expected.to validate_presence_of(:post_id) }

    it "validates checkbox_offset is >= 0" do
      contract = described_class.new(post_id: 1, checkbox_offset: -1)
      expect(contract).not_to be_valid
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic:, user:, raw: "- [ ] first\n- [x] second") }

    let(:params) { { post_id: post.id, checkbox_offset: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:checkbox_offset) { 2 }

    context "when checklist plugin is disabled" do
      before { SiteSetting.checklist_enabled = false }
      it { is_expected.to fail_a_policy(:checklist_enabled) }
    end

    context "when post is not found" do
      let(:params) { { post_id: -1, checkbox_offset: 0 } }
      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when user cannot edit the post" do
      let(:dependencies) { { guardian: Fabricate(:user).guardian } }
      it { is_expected.to fail_a_policy(:can_edit_post) }
    end

    context "when offset doesn't point to a checkbox" do
      let(:checkbox_offset) { 0 }
      it { is_expected.to fail_a_step(:validate_checkbox_at_offset) }
    end

    context "when offset points to a permanent checkbox [X]" do
      fab!(:post) { Fabricate(:post, topic:, user:, raw: "[X] permanent") }
      let(:checkbox_offset) { 0 }
      it { is_expected.to fail_a_step(:validate_checkbox_at_offset) }
    end

    context "when toggling an unchecked checkbox" do
      let(:checkbox_offset) { 2 }

      it "checks the checkbox and creates a revision" do
        expect { result }.to change { PostRevision.count }.by(1)
        expect(result).to be_success
        expect(result[:new_checked]).to be true
        expect(post.reload.raw).to eq("- [x] first\n- [x] second")
      end

      it "publishes to MessageBus" do
        messages = MessageBus.track_publish("/checklist/#{topic.id}") { result }
        expect(messages.length).to eq(1)
        expect(messages.first.data).to include(
          post_id: post.id,
          checkbox_offset: 2,
          checked: true,
        )
      end
    end

    context "when toggling a checked checkbox" do
      let(:checkbox_offset) { 14 }

      it "unchecks the checkbox" do
        expect(result[:new_checked]).to be false
        expect(post.reload.raw).to eq("- [ ] first\n- [ ] second")
      end
    end
  end
end
