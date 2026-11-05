# frozen_string_literal: true

RSpec.describe Blog::Publication::Unpublish do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with blog editorial setup"

    fab!(:publisher, :admin)
    fab!(:topic) { Fabricate(:topic, category: drafts, user: writer) }
    fab!(:first_post) do
      Fabricate(:post, topic:, user: writer, raw: "An article ready for a careful review.")
    end

    let(:params) { { topic_id: topic.id } }

    before { publish_blog_draft(publication, publisher) }

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

      it { is_expected.to fail_a_policy(:can_publish_article) }
    end

    context "when everything's ok" do
      before do
        revision = submit_blog_draft(publication, publisher)
        approve_blog_revision(publication, revision, publisher)
        publication.schedule!(publisher, revision_id: revision.id, at: 2.hours.from_now.iso8601)
      end

      it { is_expected.to run_successfully }

      it "withdraws the article, cancels its schedule and keeps the discussion" do
        result
        expect(publication.reload).to have_attributes(
          published: false,
          scheduled_at: nil,
          scheduled_revision_id: nil,
        )
        expect(publication.discussion_topic.category_id).to eq(category.id)
        expect(UserHistory.find_by(custom_type: "blog_unpublish")).to have_attributes(
          acting_user_id: acting_user.id,
          topic_id: topic.id,
        )
      end
    end
  end
end
