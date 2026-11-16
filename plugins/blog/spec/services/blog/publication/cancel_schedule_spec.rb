# frozen_string_literal: true

RSpec.describe Blog::Publication::CancelSchedule do
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

    fab!(:publisher, :admin)

    let(:params) { { topic_id: topic.id } }

    before do
      revision = submit_blog_draft(publication, writer)
      approve_blog_revision(publication, revision, publisher)
      schedule_blog_revision(publication, revision, publisher)
    end

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic does not exist" do
      let(:params) { { topic_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the topic is not an article yet" do
      fab!(:untracked) { Fabricate(:topic, category: drafts, user: writer) }

      let(:params) { { topic_id: untracked.id } }

      it "leaves no publication behind" do
        expect(result).to fail_to_find_a_model(:publication)
        expect(Blog::Publication.where(topic: untracked)).not_to exist
      end
    end

    context "when the user is not a publisher" do
      fab!(:acting_user) { writer }

      it "keeps the schedule" do
        expect(result).to fail_a_policy(:can_publish_article)
        expect(publication.reload.scheduled_at).to be_present
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "clears the schedule" do
        result
        expect(publication.reload).to have_attributes(
          scheduled_at: nil,
          scheduled_revision_id: nil,
          scheduler_id: nil,
          schedule_token: nil,
        )
      end
    end
  end
end
