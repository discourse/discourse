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

    context "with a cover image" do
      fab!(:cover) { Fabricate(:upload, user: acting_user, width: 1200, height: 630) }

      let(:metadata) { { cover_upload_id: cover.id, cover_alt: "A lighthouse at dusk" } }

      it { is_expected.to run_successfully }

      it "stages the cover and keeps its upload from being cleaned up" do
        result

        expect(publication.reload).to have_attributes(
          cover_upload_id: cover.id,
          cover_alt: "A lighthouse at dusk",
        )
        expect(UploadReference.exists?(upload: cover, target: publication)).to eq(true)
      end

      it "makes the cover the article's image when published, and keeps it through rebakes" do
        result
        publish_blog_draft(publication, acting_user)

        revision = publication.published_revision
        expect(revision.data).to include(
          "cover_upload_id" => cover.id,
          "cover_alt" => "A lighthouse at dusk",
          "image_url" => cover.url,
          "cover_width" => 1200,
          "cover_height" => 630,
        )
        expect(UploadReference.exists?(upload: cover, target: revision)).to eq(true)

        publication.refresh_article!
        expect(publication.reload.article.data["image_url"]).to eq(cover.url)
      end

      context "when a contributor picks someone else's upload" do
        fab!(:acting_user) { writer }
        fab!(:cover, :upload)

        before { topic.update!(user: writer) }

        it { is_expected.to fail_a_policy(:can_use_cover_upload) }

        it "lets them use it once they've uploaded the same file" do
          UserUpload.create!(upload: cover, user: writer)

          expect(result).to run_successfully
        end

        it "lets them keep a cover someone else chose" do
          publication.update!(cover_upload_id: cover.id)

          expect(result).to run_successfully
        end
      end

      context "when an admin picks someone else's upload" do
        fab!(:cover, :upload)

        it { is_expected.to run_successfully }
      end

      context "when the upload isn't an image" do
        fab!(:cover) do
          Fabricate(:upload, user: acting_user).tap do |upload|
            upload.update_columns(original_filename: "notes.pdf", extension: "pdf")
          end
        end

        it { is_expected.to fail_with_an_invalid_model(:publication) }
      end
    end

    context "with co-authors" do
      fab!(:ada) { Fabricate(:user, username: "ada", name: "Ada Lovelace") }
      fab!(:bob) { Fabricate(:user, username: "bob", name: "") }

      let(:metadata) { { co_authors: "Bob,ada" } }

      it { is_expected.to run_successfully }

      it "stages them in order and credits them when published" do
        result
        expect(publication.reload.co_author_ids).to eq([bob.id, ada.id])

        publish_blog_draft(publication, acting_user)

        expect(publication.co_author_ids).to eq([bob.id, ada.id])
        expect(publication.published_revision.data["co_authors"]).to eq(
          [
            { "user_id" => bob.id, "name" => "bob" },
            { "user_id" => ada.id, "name" => "Ada Lovelace" },
          ],
        )
      end

      it "keeps a published article's co-authors until the next publish" do
        publish_blog_draft(publication, acting_user)

        result
        expect(publication.reload.co_author_ids).to eq([])
        expect(publication.pending_changes).to include("co_authors")
      end

      it "removes them all with an empty list" do
        publication.update!(co_author_ids: [ada.id])

        described_class.call(params: params.merge(metadata: { co_authors: "" }), **dependencies)

        expect(publication.reload.co_author_ids).to eq([])
      end

      context "when one of them can't be credited" do
        let(:metadata) { { co_authors: "ada,nobody-here" } }

        it { is_expected.to fail_with_an_invalid_model(:publication) }
      end

      context "when the article's author is one of them" do
        let(:metadata) { { co_authors: "ada,#{acting_user.username}" } }

        it { is_expected.to fail_with_an_invalid_model(:publication) }
      end

      context "when one of them is deactivated" do
        before { ada.deactivate(Discourse.system_user) }

        it { is_expected.to fail_with_an_invalid_model(:publication) }
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
