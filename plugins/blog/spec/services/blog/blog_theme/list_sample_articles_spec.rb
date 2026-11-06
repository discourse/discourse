# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::ListSampleArticles do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with a public blog"

    fab!(:acting_user, :admin)
    fab!(:older_publication) { publish_blog_article(published_at: 2.days.ago) }
    fab!(:newer_publication) { publish_blog_article(published_at: 1.day.ago) }
    fab!(:private_publication) do
      publish_blog_article(
        Fabricate(:topic, category: Fabricate(:private_category, group: Group[:staff])),
        published_at: 1.hour.ago,
      )
    end

    let(:params) { {} }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_manage_themes) }
    end

    context "when the requested article is not a public sample" do
      let(:params) { { article_id: private_publication.id } }

      it { is_expected.to fail_a_policy(:requested_article_is_sample) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "offers public articles newest first and samples the newest" do
        expect(result.publications).to eq([newer_publication, older_publication])
        expect(result.publication).to eq(newer_publication)
      end
    end

    context "when an article is requested" do
      let(:params) { { article_id: older_publication.id } }

      it "samples the requested article" do
        expect(result.publication).to eq(older_publication)
      end
    end
  end
end
