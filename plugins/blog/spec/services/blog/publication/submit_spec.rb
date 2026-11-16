# frozen_string_literal: true

RSpec.describe Blog::Publication::Submit do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with blog editorial setup"

    fab!(:topic) { Fabricate(:topic, category: drafts, user: acting_user) }
    fab!(:first_post) do
      Fabricate(:post, topic:, user: acting_user, raw: "An article ready for a careful review.")
    end

    let(:params) { { topic_id: topic.id } }

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic does not exist" do
      let(:params) { { topic_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when a contributor submits someone else's article" do
      fab!(:acting_user) { writer }

      it { is_expected.to fail_a_policy(:can_edit_article) }
    end

    context "when the blog is not ready" do
      before { SiteSetting.prevent_anons_from_downloading_files = true }

      it { is_expected.to fail_a_policy(:blog_ready) }
    end

    context "when a discussion without a working copy cannot be copied" do
      fab!(:discussion) { Fabricate(:topic, category:, user: acting_user, archived: true) }

      let(:params) { { topic_id: discussion.id } }

      before { Fabricate(:post, topic: discussion, user: acting_user) }

      it { is_expected.to fail_a_policy(:draftable) }
    end

    context "when the working copy is archived" do
      before { topic.update!(archived: true) }

      it { is_expected.to fail_a_policy(:working_copy_publishable) }
    end

    context "when everything's ok" do
      before do
        previous = submit_blog_draft(publication, acting_user)
        approve_blog_revision(publication, previous, acting_user)
      end

      it { is_expected.to run_successfully }

      it "freezes the working copy as a revision awaiting approval" do
        revision = result[:revision]
        expect(revision).to have_attributes(
          source_topic: topic,
          creator: acting_user,
          title: topic.title,
          raw: first_post.raw,
        )
        expect(publication.reload).to have_attributes(
          submitted_revision: revision,
          approved_revision: nil,
        )
      end

      it "logs the submission" do
        revision = result[:revision]
        expect(UserHistory.where(custom_type: "blog_submit").last).to have_attributes(
          acting_user_id: acting_user.id,
          topic_id: topic.id,
          details: "revision_id: #{revision.id}",
        )
      end
    end
  end
end
