# frozen_string_literal: true

RSpec.describe Blog::Publication::Approve do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:revision_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with blog editorial setup"

    fab!(:topic) { Fabricate(:topic, category: drafts, user: writer) }
    fab!(:first_post) do
      Fabricate(:post, topic:, user: writer, raw: "An article ready for a careful review.")
    end

    let(:params) { { topic_id: topic.id, revision_id: revision.id } }
    let(:revision) { submit_blog_draft(publication, writer) }

    context "when contract is invalid" do
      let(:params) { { topic_id: topic.id } }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic does not exist" do
      let(:params) { super().merge(topic_id: 0) }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the user is not a publisher" do
      fab!(:acting_user) { writer }

      it { is_expected.to fail_a_policy(:can_publish_article) }
    end

    context "when the revision belongs to another article" do
      fab!(:other_topic) { Fabricate(:topic, category: drafts, user: writer) }

      let(:revision) do
        Fabricate(:post, topic: other_topic, user: writer)
        submit_blog_draft(Blog::Publication.for_topic(other_topic), writer)
      end

      it { is_expected.to fail_to_find_a_model(:revision) }
    end

    context "when a newer submission superseded the revision" do
      before do
        revision
        submit_blog_draft(publication, writer)
      end

      it { is_expected.to fail_a_policy(:revision_is_latest_submission) }
    end

    context "when another publisher already approved the revision" do
      fab!(:first_approver, :admin)

      before do
        freeze_time 1.hour.ago
        approve_blog_revision(publication, revision, first_approver)
        unfreeze_time
      end

      it { is_expected.to run_successfully }

      it "keeps the original approval provenance" do
        expect { result }.not_to change {
          revision.reload.attributes.slice("approver_id", "approved_at")
        }
      end
    end

    context "when everything's ok" do
      before { freeze_time }

      it { is_expected.to run_successfully }

      it "approves the revision and logs it" do
        result
        expect(revision.reload).to have_attributes(
          approver: acting_user,
          approved_at: eq_time(Time.current),
        )
        expect(publication.reload.approved_revision).to eq(revision)
        expect(UserHistory.find_by(custom_type: "blog_approve")).to have_attributes(
          acting_user_id: acting_user.id,
          topic_id: topic.id,
          details: "revision_id: #{revision.id}",
        )
      end
    end
  end
end
