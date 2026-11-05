# frozen_string_literal: true

RSpec.describe Blog::Publication::Publish do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with blog editorial setup"

    fab!(:topic) { Fabricate(:topic, category: drafts, user: writer) }
    fab!(:first_post) do
      Fabricate(:post, topic:, user: writer, raw: "An article ready for a careful review.")
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

    context "when the user is not a publisher" do
      fab!(:acting_user) { writer }

      it "publishes nothing and leaves no submission behind" do
        expect(result).to fail_a_policy(:can_publish_article)
        expect(Blog::Publication.where(topic:)).not_to exist
      end
    end

    context "when the blog is not ready" do
      before { SiteSetting.prevent_anons_from_downloading_files = true }

      it { is_expected.to fail_a_policy(:blog_ready) }
    end

    context "without a revision" do
      it { is_expected.to run_successfully }

      it "submits, approves and publishes the current draft" do
        result
        published = publication.reload
        expect(published).to be_published
        expect(published.published_revision).to have_attributes(
          raw: first_post.raw,
          approver: acting_user,
        )
        expect(published.submitted_revision).to eq(published.published_revision)
        expect(
          UserHistory.where(custom_type: %w[blog_submit blog_approve blog_publish]).count,
        ).to eq(3)
      end
    end

    context "when the current draft cannot be submitted" do
      before do
        publication.update!(draft_topic: topic)
        topic.update!(archived: true)
      end

      it { is_expected.to fail_a_step(:submit_current_draft) }
    end

    context "with a revision" do
      let(:revision) { submit_blog_draft(publication, writer) }
      let(:params) { { topic_id: topic.id, revision_id: revision.id } }

      context "when the revision belongs to another article" do
        fab!(:other_topic) { Fabricate(:topic, category: drafts, user: writer) }

        let(:revision) do
          Fabricate(:post, topic: other_topic, user: writer)
          submit_blog_draft(Blog::Publication.for_topic(other_topic), writer)
        end

        it { is_expected.to fail_to_find_a_model(:revision) }
      end

      context "when the revision is not approved" do
        it "publishes nothing" do
          expect { result }.to raise_error(Discourse::InvalidParameters)
          expect(publication.reload).not_to be_published
        end
      end

      context "when the revision is approved" do
        before { approve_blog_revision(publication, revision, acting_user) }

        it { is_expected.to run_successfully }

        it "publishes that revision" do
          result
          expect(publication.reload).to have_attributes(
            published?: true,
            published_revision: revision,
            publisher: acting_user,
          )
        end
      end
    end
  end
end
