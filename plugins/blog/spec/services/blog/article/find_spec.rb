# frozen_string_literal: true

RSpec.describe Blog::Article::Find do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:path) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with a public blog"

    fab!(:publication) { publish_blog_article(path: "/current-story") }

    let(:params) { { path: } }
    let(:dependencies) { { guardian: Guardian.new } }
    let(:path) { publication.path }

    context "when contract is invalid" do
      let(:path) { "" }

      it { is_expected.to fail_a_contract }
    end

    context "when no article was ever published at the path" do
      let(:path) { "/unknown-story" }

      it { is_expected.to fail_to_find_a_model(:stored_path) }
    end

    context "when the article is no longer public" do
      before { publication.update!(published: false) }

      it { is_expected.to fail_to_find_a_model(:publication) }
    end

    context "when the article has since moved to another path" do
      let(:path) { "/earlier-story" }

      before { publication.paths.create!(path:) }

      it { is_expected.to fail_a_policy(:requested_path_is_current) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "finds the article" do
        expect(result.publication).to eq(publication)
      end
    end
  end
end
