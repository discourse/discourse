# frozen_string_literal: true

RSpec.describe Blog::Article::List do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(page:, query:, tag_slug:, archive:) }

    let(:page) { nil }
    let(:query) { nil }
    let(:tag_slug) { nil }
    let(:archive) { nil }

    before { contract.validate }

    context "with a page below the first" do
      let(:page) { "-2" }

      it "starts on the first page" do
        expect(contract.page).to eq(1)
      end
    end

    context "with a padded, over-long query" do
      let(:query) { "  #{"a" * 150}  " }

      it "strips the query and caps its length" do
        expect(contract.query).to eq("a" * Blog::Article::List::MAX_QUERY_LENGTH)
      end
    end

    context "with a query containing LIKE wildcards" do
      let(:query) { "100%_off" }

      it "matches them literally" do
        expect(contract.search_pattern).to eq("%100\\%\\_off%")
      end
    end

    it "puts featured articles first on the unfiltered listing" do
      expect(contract).to be_featured_first
    end

    context "with a query" do
      let(:query) { "needle" }

      it { is_expected.not_to be_featured_first }
    end

    context "with a tag" do
      let(:tag_slug) { "notes" }

      it { is_expected.not_to be_featured_first }
    end

    context "with the archive" do
      let(:archive) { true }

      it { is_expected.not_to be_featured_first }
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with a public blog"

    fab!(:tag) { Fabricate(:tag, name: "field-notes") }
    fab!(:hidden_tag) { Fabricate(:tag, name: "staff-notes") }
    fab!(:tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    end
    fab!(:older_publication) do
      publish_article_tagged(tag, published_at: 3.days.ago, excerpt: "Notes on a needle")
    end
    fab!(:featured_publication) { publish_blog_article(published_at: 2.days.ago, featured: true) }
    fab!(:newer_publication) { publish_blog_article(published_at: 1.day.ago) }
    fab!(:private_publication) do
      publish_blog_article(
        Fabricate(:topic, category: Fabricate(:private_category, group: Group[:staff])),
      )
    end

    let(:params) { {} }
    let(:dependencies) { { guardian: Guardian.new } }

    def publish_article_tagged(tag, **attributes)
      publish_blog_article(Fabricate(:topic, category: blog_category, tags: [tag]), **attributes)
    end

    context "when the requested tag is not visible to everyone" do
      let(:params) { { tag_slug: hidden_tag.slug } }

      it { is_expected.to fail_a_policy(:requested_tag_is_visible) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "lists public articles with featured ones first, then newest first" do
        expect(result.listing).to eq(
          publications: [featured_publication, newer_publication, older_publication],
          has_more: false,
        )
      end
    end

    context "when searching" do
      let(:params) { { query: "NEEDLE" } }

      it "lists only articles whose title or excerpt matches" do
        expect(result.listing[:publications]).to contain_exactly(older_publication)
      end
    end

    context "when a tag is requested" do
      let(:params) { { tag_slug: tag.slug } }

      it "lists only articles with that tag" do
        expect(result.tag).to eq(tag)
        expect(result.listing[:publications]).to contain_exactly(older_publication)
      end
    end

    context "when listing the archive" do
      let(:params) { { archive: true } }

      it "lists articles newest first regardless of featuring" do
        expect(result.listing[:publications]).to eq(
          [newer_publication, featured_publication, older_publication],
        )
      end
    end

    context "with more articles than fit on a page" do
      let(:params) { { page: 2 } }

      before { SiteSetting.blog_posts_per_page = 1 }

      it "lists the requested page and reports that more follow" do
        expect(result.listing).to eq(publications: [newer_publication], has_more: true)
      end
    end
  end
end
