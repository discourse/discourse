# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::CreateWorkingPreview do
  describe described_class::Contract, type: :model do
    it do
      is_expected.to validate_inclusion_of(:page).in_array(
        Blog::BlogTheme::CreateWorkingPreview::PAGES,
      )
    end

    context "when previewing an article" do
      subject(:contract) { described_class.new(page: "article") }

      it { is_expected.to validate_presence_of(:article_id) }
    end

    describe "#static_page_path" do
      it "maps listing pages to their blog paths" do
        expect(described_class.new(page: "archive").static_page_path).to eq("/archive")
      end

      it "picks a path no article can occupy for the not-found page" do
        expect(described_class.new(page: "not_found").static_page_path).to match(
          %r{\A/theme-preview-not-found-\h{32}\z},
        )
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category:) }
    fab!(:first_post) { Fabricate(:post, topic:) }

    let(:attributes) do
      {
        name: "Unsaved design",
        accent_color: "112233",
        paper_color: "fafafa",
        ink_color: "222222",
        css: "",
        javascript: "",
        template_index: "{% unknown_tag %}",
      }
    end
    let(:params) { attributes.merge(page: "index") }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before { enable_blog!(category:) }

    context "when contract is invalid" do
      let(:params) { attributes.merge(page: "settings") }

      it { is_expected.to fail_a_contract }
    end

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_manage_themes) }
    end

    context "when the article is not public" do
      let(:params) { attributes.merge(page: "article", article_id: -1) }

      it { is_expected.to fail_to_find_a_model(:preview_path) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "holds the unsaved fields, including unparseable templates, for the preview" do
        expect(Blog::ThemePreview.theme_for(result.preview_token)).to include(
          "name" => "Unsaved design",
          "template_index" => "{% unknown_tag %}",
        )
        expect(result.preview_path).to eq("/")
        expect(Blog::BlogTheme.all).to be_empty
      end
    end

    context "when previewing a public article" do
      fab!(:publication) do
        Blog::Publication.create!(
          topic:,
          discussion_topic: topic,
          path: "/sample",
          published: true,
          published_at: 1.day.ago,
        )
      end

      let(:params) { attributes.merge(page: "article", article_id: publication.id) }

      it "previews the article's path" do
        expect(result.preview_path).to eq(publication.path)
      end
    end
  end
end
