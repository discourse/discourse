# frozen_string_literal: true

RSpec.describe Blog::Publication::PrepareDraft do
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
    fab!(:discussion) { Fabricate(:topic, category:, user: acting_user) }
    fab!(:discussion_post) do
      Fabricate(
        :post,
        topic: discussion,
        user: acting_user,
        raw: "A public discussion that becomes an article.",
      )
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

    context "when a contributor edits someone else's article" do
      fab!(:acting_user) { writer }

      it { is_expected.to fail_a_policy(:can_edit_article) }
    end

    context "when the blog is not ready" do
      before { SiteSetting.prevent_anons_from_downloading_files = true }

      it { is_expected.to fail_a_policy(:blog_ready) }
    end

    context "when the discussion cannot be copied into drafts" do
      let(:params) { { topic_id: discussion.id } }

      before { discussion.update!(archived: true) }

      it { is_expected.to fail_a_policy(:draftable) }
    end

    context "when the topic is already in drafts" do
      it { is_expected.to run_successfully }

      it "uses the topic as the working copy" do
        expect { result }.not_to change { Topic.count }
        expect(Blog::Publication.for_topic(topic).draft_topic).to eq(topic)
      end
    end

    context "with a Blog-category discussion" do
      let(:params) { { topic_id: discussion.id } }

      it { is_expected.to run_successfully }

      it "copies the discussion into drafts as the working copy" do
        expect { result }.to change { Topic.count }.by(1)
        working_copy = Blog::Publication.for_topic(discussion).draft_topic
        expect(working_copy).to have_attributes(
          category_id: drafts.id,
          title: discussion.title,
          user_id: acting_user.id,
        )
        expect(working_copy.first_post.raw).to eq(discussion_post.raw)
        expect(discussion.reload).to have_attributes(category_id: category.id, posts_count: 1)
      end
    end
  end
end
