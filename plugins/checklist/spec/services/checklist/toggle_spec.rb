# frozen_string_literal: true

RSpec.describe Checklist::Toggle do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(post_id: 1, checkbox_offset: 0) }

    it { is_expected.to validate_presence_of(:post_id) }

    it "validates checkbox_offset is >= 0" do
      contract = described_class.new(post_id: 1, checkbox_offset: -1)
      expect(contract).not_to be_valid
      expect(contract.errors[:checkbox_offset]).to be_present
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic:, user:, raw: "- [ ] first\n- [x] second\n- [ ] third") }

    # Offsets: "- [ ] first\n" = 12 chars, so:
    # - [ ] at offset 2
    # - [x] at offset 14 (12 + 2)
    # - [ ] at offset 26 (12 + 12 + 2)
    let(:post_id) { post.id }
    let(:checkbox_offset) { 2 }
    let(:params) { { post_id:, checkbox_offset: } }
    let(:dependencies) { { guardian: user.guardian } }

    context "when user cannot edit the post" do
      fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
      let(:dependencies) { { guardian: other_user.guardian } }

      it { is_expected.to fail_a_policy(:can_edit_post) }
    end

    context "when checklist plugin is disabled" do
      before { SiteSetting.checklist_enabled = false }

      it { is_expected.to fail_a_policy(:checklist_enabled) }
    end

    context "when contract is invalid" do
      let(:checkbox_offset) { -1 }

      it { is_expected.to fail_a_contract }
    end

    context "when post is not found" do
      let(:post_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when offset is out of bounds" do
      let(:checkbox_offset) { 9999 }

      it { is_expected.to fail_a_step(:validate_checkbox_at_offset) }
    end

    context "when offset doesn't point to a checkbox" do
      let(:checkbox_offset) { 0 } # points to "-" not "["

      it { is_expected.to fail_a_step(:validate_checkbox_at_offset) }
    end

    context "when toggling an unchecked checkbox" do
      let(:checkbox_offset) { 2 } # first checkbox at "- [ ]"

      it { is_expected.to run_successfully }

      it "checks the checkbox" do
        expect(result[:new_checked]).to be true
      end

      it "updates the post raw" do
        result
        post.reload
        expect(post.raw).to eq("- [x] first\n- [x] second\n- [ ] third")
      end

      it "creates a revision" do
        expect { result }.to change { PostRevision.count }.by(1)
      end

      it "publishes to MessageBus" do
        messages = MessageBus.track_publish("/checklist/#{post.topic_id}") { result }

        expect(messages.length).to eq(1)
        expect(messages.first.data).to include(post_id: post.id, checkbox_offset: 2, checked: true)
      end
    end

    context "when toggling a checked checkbox" do
      let(:checkbox_offset) { 14 } # second checkbox at "[x] second"

      it { is_expected.to run_successfully }

      it "unchecks the checkbox" do
        expect(result[:new_checked]).to be false
      end

      it "updates the post raw" do
        result
        post.reload
        expect(post.raw).to eq("- [ ] first\n- [ ] second\n- [ ] third")
      end
    end

    context "with image alt text that looks like checkbox" do
      fab!(:post) { Fabricate(:post, topic:, user:, raw: "![](image.png) text") }

      let(:checkbox_offset) { 1 } # points to [] in ![]

      it { is_expected.to fail_a_step(:validate_checkbox_at_offset) }
    end

    context "with escaped checkbox" do
      fab!(:post) { Fabricate(:post, topic:, user:, raw: "\\[ ] escaped checkbox") }

      let(:checkbox_offset) { 1 } # points to [ ] after backslash

      it { is_expected.to fail_a_step(:validate_checkbox_at_offset) }
    end

    context "with permanent checkbox [X]" do
      fab!(:post) { Fabricate(:post, topic:, user:, raw: "[X] permanent checkbox") }

      let(:checkbox_offset) { 0 }

      it { is_expected.to fail_a_step(:validate_checkbox_at_offset) }

      it "does not modify the post" do
        result
        post.reload
        expect(post.raw).to eq("[X] permanent checkbox")
      end
    end

    context "with checkbox after code block" do
      fab!(:post) do
        Fabricate(:post, topic:, user:, raw: "```ruby\n# comment\nend\n```\n\n[ ] real checkbox")
      end

      # Real checkbox starts at position 27
      let(:checkbox_offset) { 27 }

      it { is_expected.to run_successfully }

      it "toggles the real checkbox" do
        result
        post.reload
        expect(post.raw).to include("[x] real checkbox")
      end
    end
  end
end
