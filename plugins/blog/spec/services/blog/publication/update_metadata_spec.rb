# frozen_string_literal: true

RSpec.describe Blog::Publication::UpdateMetadata do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:metadata) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with blog editorial setup"

    fab!(:topic) { Fabricate(:topic, category: drafts, user: acting_user) }
    fab!(:first_post) do
      Fabricate(:post, topic:, user: acting_user, raw: "An article ready for a careful review.")
    end

    let(:params) { { topic_id: topic.id, metadata: } }
    let(:metadata) { { path: "/fresh-story", excerpt: "A short summary." } }

    context "when contract is invalid" do
      let(:metadata) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic does not exist" do
      let(:params) { super().merge(topic_id: 0) }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the blog is not ready" do
      before { SiteSetting.prevent_anons_from_downloading_files = true }

      it { is_expected.to fail_a_policy(:blog_ready) }
    end

    context "when the metadata is invalid" do
      let(:metadata) { { path: "/about" } }

      it { is_expected.to fail_with_an_invalid_model(:publication) }
    end

    context "when a contributor edits someone else's article" do
      fab!(:acting_user) { writer }

      it { is_expected.to fail_a_policy(:can_edit_article) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "stores the metadata and logs the new path" do
        result
        expect(publication).to have_attributes(path: "/fresh-story", excerpt: "A short summary.")
        expect(UserHistory.find_by(custom_type: "blog_metadata")).to have_attributes(
          acting_user_id: acting_user.id,
          topic_id: topic.id,
          details: "path: /fresh-story",
        )
      end
    end

    context "with a published article" do
      let(:metadata) { { path: "/fresh-story", published_at: "" } }

      before { publish_blog_draft(publication, acting_user) }

      it { is_expected.to run_successfully }

      it "stages the changes while the live values stay in place" do
        expect { result }.not_to change { publication.reload.path }
        expect(publication.editorial_metadata).to include(
          "path" => "/fresh-story",
          "published_at" => publication.published_at.as_json,
        )
      end
    end

    context "with search metadata on a published article" do
      let(:metadata) do
        { meta_description: "For search engines.", canonical_url: "https://example.com/original" }
      end

      before { publish_blog_draft(publication, acting_user) }

      it "stages it as a pending change until the next publish" do
        result
        publication.reload

        expect(publication).to have_attributes(meta_description: "", canonical_url: "")
        expect(publication.pending_changes).to include("meta_description", "canonical_url")

        publish_blog_draft(publication, acting_user)

        expect(publication).to have_attributes(
          meta_description: "For search engines.",
          canonical_url: "https://example.com/original",
          display_description: "For search engines.",
          canonical_article_url: "https://example.com/original",
        )
      end

      it "doesn't report changes for articles published before these fields existed" do
        data = publication.published_revision.data.except("meta_description", "canonical_url")
        Blog::Revision.where(id: publication.published_revision_id).update_all(data:)

        expect(publication.reload.pending_changes).not_to include(
          "meta_description",
          "canonical_url",
        )
      end
    end

    context "with a dated path format" do
      let(:metadata) { { path: "/2026/11/#{topic.slug}", published_at: "2025-03-14" } }

      before do
        freeze_time Time.utc(2026, 11, 6)
        SiteSetting.blog_path_format = "/{year}/{month}/{slug}"
      end

      it "moves a draft's generated path to its publication date" do
        result
        expect(Blog::Publication.find_by(topic:).path).to eq("/2025/03/#{topic.slug}")
      end

      it "keeps a published article's path when its date changes" do
        publish_blog_draft(publication, acting_user)

        result
        expect(publication.reload.editorial_metadata["path"]).to eq("/2026/11/#{topic.slug}")
      end
    end
  end
end
