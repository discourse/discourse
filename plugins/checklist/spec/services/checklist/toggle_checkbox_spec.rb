# frozen_string_literal: true

RSpec.describe Checklist::ToggleCheckbox do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
    it { is_expected.to allow_values(0, 3).for(:checkbox_index) }
    it { is_expected.not_to allow_values(-1, nil).for(:checkbox_index) }
    it { is_expected.to allow_values(1, 10).for(:checkbox_count) }
    it { is_expected.not_to allow_values(0, -1, nil).for(:checkbox_count) }
    it { is_expected.to allow_values(true, false).for(:checked) }
    it { is_expected.not_to allow_value(nil).for(:checked) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic) { Fabricate(:topic, user: user) }

    fab!(:post) { Fabricate(:post, topic: topic, user: user, raw: "- [ ] first\n- [x] second") }

    let(:params) { { post_id:, checkbox_index:, checkbox_count:, checked: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:post_id) { post.id }
    let(:checkbox_index) { 0 }
    let(:checkbox_count) { 2 }
    let(:checked) { true }

    context "when the contract is invalid" do
      let(:checkbox_index) { -1 }

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

    context "when the post has no checkboxes" do
      before { post.update_columns(raw: "no boxes here") }

      let(:checkbox_count) { 1 }

      it { is_expected.to fail_to_find_a_model(:checkboxes) }
    end

    context "when the client checkbox count is stale" do
      let(:checkbox_count) { 5 }

      it { is_expected.to fail_a_policy(:checkboxes_unchanged) }
    end

    context "when the checkbox index is out of bounds" do
      let(:checkbox_index) { 2 }

      it { is_expected.to fail_to_find_a_model(:checkbox) }
    end

    context "when the checkbox is permanent" do
      before { post.update_columns(raw: "[X] permanent\n[x] not permanent") }

      it { is_expected.to fail_a_policy(:checkbox_toggleable) }
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

      it "creates a revision" do
        expect { result }.to change { PostRevision.count }.by(1)
      end

      it "does not bump the topic" do
        expect { result }.not_to change { topic.reload.bumped_at }
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
