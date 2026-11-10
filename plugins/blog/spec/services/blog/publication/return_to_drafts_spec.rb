# frozen_string_literal: true

RSpec.describe Blog::Publication::ReturnToDrafts do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with blog editorial setup"

    fab!(:topic) { Fabricate(:topic, category:, user: writer) }
    fab!(:first_post) do
      Fabricate(:post, topic:, user: writer, raw: "A live article that needs another pass.")
    end

    let(:params) { { topic_id: topic.id } }
    let(:publication) { Blog::Publication.find_by(topic:) }

    before do
      Blog::Publication.create!(
        topic:,
        path: "/live-story",
        published: true,
        published_at: 1.day.ago,
        publisher: acting_user,
      )
    end

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic does not exist" do
      let(:params) { { topic_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the topic was never published" do
      fab!(:untracked) { Fabricate(:topic, category:, user: writer) }
      fab!(:untracked_post) { Fabricate(:post, topic: untracked, user: writer) }

      let(:params) { { topic_id: untracked.id } }

      it "leaves no publication or working copy behind" do
        expect { result }.not_to change { Topic.count }
        expect(result).to fail_to_find_a_model(:publication)
        expect(Blog::Publication.where(topic: untracked)).not_to exist
      end
    end

    context "when the user is not a publisher" do
      fab!(:acting_user) { writer }

      it { is_expected.to fail_a_policy(:can_publish_article) }
    end

    context "when the blog is not ready" do
      before { SiteSetting.prevent_anons_from_downloading_files = true }

      it "keeps the article published" do
        expect(result).to fail_a_policy(:blog_ready)
        expect(publication.reload).to be_published
      end
    end

    context "when the article cannot be copied into drafts" do
      before { topic.update!(archived: true) }

      it "keeps the article published" do
        expect(result).to fail_a_policy(:draftable)
        expect(publication.reload).to be_published
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "withdraws the article into a private working copy" do
        expect { result }.to change { Topic.count }.by(1)
        expect(publication.reload).not_to be_published
        expect(publication.draft_topic).to have_attributes(
          category_id: drafts.id,
          title: topic.title,
        )
        expect(UserHistory.find_by(custom_type: "blog_unpublish")).to have_attributes(
          acting_user_id: acting_user.id,
          topic_id: topic.id,
        )
      end
    end
  end
end
