# frozen_string_literal: true

RSpec.describe Checklist::ToggleCheckbox do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
    it { is_expected.to validate_presence_of(:toggles) }

    it "limits the batch size" do
      toggles =
        Array.new(Checklist::ToggleCheckbox::MAX_BATCH_SIZE + 1) do |index|
          { checkbox_index: index, checkbox_source: "0:#{index}", checked: true }
        end
      contract =
        described_class.new(
          post_id: 1,
          toggles:,
          expected_raw: "[ ] task",
          expected_updated_at: Time.zone.now.iso8601,
          mutation_id: "mutation",
        )

      expect(contract).not_to be_valid
      expect(contract.errors[:toggles]).to be_present
    end

    it { is_expected.to validate_presence_of(:expected_raw) }
    it { is_expected.to validate_length_of(:expected_raw).is_at_most(SiteSetting.max_post_length) }
    it { is_expected.to validate_presence_of(:expected_updated_at) }
    it { is_expected.to validate_presence_of(:mutation_id) }
    it { is_expected.to validate_length_of(:mutation_id).is_at_most(100) }
  end

  describe ".retryable_conflict?" do
    fab!(:post) { Fabricate(:post, raw: "[] first\n[X] fixed") }

    it "normalizes legacy mutable markers but not permanent markers" do
      expect(
        described_class.retryable_conflict?(post:, expected_raw: "[x] first\n[X] fixed"),
      ).to eq(true)
      expect(described_class.retryable_conflict?(post:, expected_raw: "[] first\n[x] fixed")).to eq(
        false,
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic) { Fabricate(:topic, user: user) }

    fab!(:post) { Fabricate(:post, topic: topic, user: user, raw: "- [ ] first\n- [x] second") }

    let(:params) do
      {
        post_id:,
        toggles: [{ checkbox_index:, checkbox_count:, checkbox_source:, checked: }],
        expected_raw:,
        expected_updated_at:,
        mutation_id:,
      }
    end
    let(:dependencies) { { guardian: user.guardian } }
    let(:post_id) { post.id }
    let(:checkbox_index) { 0 }
    let(:checkbox_count) { 2 }
    let(:checkbox_source) { nil }
    let(:checked) { true }
    let(:expected_raw) { post.raw }
    let(:expected_updated_at) { post.updated_at.iso8601(3) }
    let(:mutation_id) { "mutation-123" }

    context "when the contract is invalid" do
      let(:checkbox_index) { -1 }

      it { is_expected.to fail_a_contract }
    end

    context "when a malformed source is provided with a valid count" do
      let(:checkbox_source) { "invalid" }

      it { is_expected.to fail_a_contract }
    end

    context "when checklist is disabled" do
      before { SiteSetting.checklist_enabled = false }

      it { is_expected.to fail_a_policy(:checklist_enabled) }
    end

    context "when the post does not exist" do
      let(:post_id) { -1 }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when the user cannot edit the post" do
      fab!(:another_user, :user)

      let(:dependencies) { { guardian: another_user.guardian } }

      it { is_expected.to fail_a_policy(:can_edit_post) }
    end

    context "when the post changed after the client rendered it" do
      let(:expected_updated_at) { 1.minute.ago.iso8601(3) }

      it { is_expected.to fail_a_policy(:post_unchanged) }
    end

    context "when the post has no checkboxes" do
      before { post.update_columns(raw: "no boxes here") }

      let(:checkbox_count) { 1 }

      it { is_expected.to fail_a_policy(:checkbox_counts_unchanged) }
    end

    context "when the client checkbox count is stale" do
      let(:checkbox_count) { 5 }

      it { is_expected.to fail_a_policy(:checkbox_counts_unchanged) }
    end

    context "when the checkbox index is out of bounds" do
      let(:checkbox_index) { 2 }

      it { is_expected.to fail_a_policy(:checkboxes_found) }
    end

    context "when a source hint is provided" do
      let(:checkbox_source) { "1:0" }
      let(:checkbox_count) { 99 }
      let(:checked) { false }

      it "uses the source hint without validating the rendered count" do
        expect { result }.to change { post.reload.raw }.to("- [ ] first\n- [ ] second")
      end
    end

    context "when multiple checkbox changes are batched" do
      before do
        SiteSetting.editing_grace_period = 0
        post.update!(raw: "[ ] first\n[x] second\n[] third")
      end

      let(:params) do
        {
          post_id: post.id,
          toggles: [
            { checkbox_index: 0, checkbox_source: "0:0", checked: true },
            { checkbox_index: 2, checkbox_source: "2:0", checked: true },
          ],
          expected_raw: post.raw,
          expected_updated_at: post.updated_at.iso8601(3),
          mutation_id:,
        }
      end

      it "applies the batch in one revision" do
        expect { result }.to change { PostRevision.count }.by(1)
        expect(post.reload.raw).to eq("[x] first\n[x] second\n[x] third")
      end
    end

    context "when one checkbox in a batch is permanent" do
      before { post.update!(raw: "[ ] first\n[X] permanent") }

      let(:params) do
        {
          post_id: post.id,
          toggles: [
            { checkbox_index: 0, checkbox_source: "0:0", checked: true },
            { checkbox_index: 1, checkbox_count: 2, checked: false },
          ],
          expected_raw: post.raw,
          expected_updated_at: post.updated_at.iso8601(3),
          mutation_id:,
        }
      end

      it { is_expected.to fail_a_policy(:checkboxes_toggleable) }

      it "does not apply the valid part of the batch" do
        expect { result }.not_to change { post.reload.raw }
      end
    end

    context "when the checkbox is permanent" do
      before { post.update_columns(raw: "[X] permanent\n[x] not permanent") }

      it { is_expected.to fail_a_policy(:checkboxes_toggleable) }
    end

    context "when the checkbox is already in the desired state" do
      let(:checked) { false }

      it { is_expected.to run_successfully }

      it "does not change the raw" do
        expect { result }.not_to change { post.reload.raw }
      end

      it "does not create a revision" do
        expect { result }.not_to change { PostRevision.count }
      end
    end

    context "when checking an unchecked checkbox" do
      before { SiteSetting.editing_grace_period = 0 }

      it { is_expected.to run_successfully }

      it "checks the checkbox" do
        expect { result }.to change { post.reload.raw }.to("- [x] first\n- [x] second")
      end

      it "stores source hints for subsequent toggles" do
        result

        expect(post.reload.cooked).to include("data-chk-src")
      end

      it "creates a revision" do
        expect { result }.to change { PostRevision.count }.by(1)
      end

      it "does not bump the topic and preserves the editor's rendered content" do
        messages =
          MessageBus.track_publish("/topic/#{topic.id}") do
            expect { result }.not_to change { topic.reload.bumped_at }
          end
        revised_message = messages.find { |message| message.data[:type] == :revised }

        expect(revised_message.data[:preserve_cooked_token]).to eq(mutation_id)
      end
    end

    context "when unchecking a checked checkbox" do
      let(:checkbox_index) { 1 }
      let(:checked) { false }

      it { is_expected.to run_successfully }

      it "unchecks the checkbox" do
        expect { result }.to change { post.reload.raw }.to("- [ ] first\n- [ ] second")
      end
    end

    context "when the post revision fails" do
      before { PostRevisor.any_instance.stubs(:revise!).returns(false) }

      it { is_expected.to fail_a_step(:revise_post) }

      it "returns a stable failure reason" do
        expect(result["result.step.revise_post"].error).to eq(:revision_failed)
      end
    end

    context "when the raw contains multibyte characters" do
      before { post.update_columns(raw: "🎉 party time\n\n[ ] bring the cake") }

      let(:checkbox_count) { 1 }

      it { is_expected.to run_successfully }

      it "checks the checkbox" do
        expect { result }.to change { post.reload.raw }.to("🎉 party time\n\n[x] bring the cake")
      end
    end

    context "when the post uses legacy empty checkboxes" do
      before { post.update_columns(raw: "[] first thing\n[] second thing") }

      it { is_expected.to run_successfully }

      it "checks the checkbox" do
        expect { result }.to change { post.reload.raw }.to("[x] first thing\n[] second thing")
      end
    end
  end
end
