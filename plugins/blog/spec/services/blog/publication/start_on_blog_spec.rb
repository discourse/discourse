# frozen_string_literal: true

RSpec.describe Blog::Publication::StartOnBlog do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:blog_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with blog editorial setup"

    fab!(:topic) { Fabricate(:topic, category: drafts, user: acting_user) }
    fab!(:first_post) { Fabricate(:post, topic:, user: acting_user) }

    let(:engineering) do
      Blog::Instance.create!(
        name: "Engineering",
        slug: "engineering",
        path_format: "/{year}/{slug}",
      )
    end
    let(:params) { { topic_id: topic.id, blog_id: engineering.id } }

    context "when contract is invalid" do
      let(:params) { { topic_id: topic.id } }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic is not a draft" do
      let(:params) { super().merge(topic_id: Fabricate(:topic, category:).id) }

      it { is_expected.to fail_a_policy(:editorial_draft) }
    end

    context "when the user cannot edit the draft" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_a_policy(:can_edit_draft) }
    end

    context "when the blog does not exist" do
      let(:params) { super().merge(blog_id: 0) }

      it { is_expected.to fail_to_find_a_model(:blog) }
    end

    context "when the blog is the default blog" do
      let(:params) { super().merge(blog_id: Blog::Instance.default_blog.id) }

      it "records nothing, as drafts belong to it already" do
        expect(result).to fail_a_policy(:blog_is_not_default)
        expect(Blog::Publication.where(topic:)).not_to exist
      end
    end

    context "when another article on the blog holds the generated path" do
      before do
        taken = Blog::Publication.create!(topic: Fabricate(:topic), blog: engineering, path: "/x")
        taken.paths.create!(path: "/#{Time.current.year}/#{topic.slug}")
      end

      it "adds the topic id to the path" do
        expect(result[:publication]).to have_attributes(
          blog_id: engineering.id,
          path: "/#{Time.current.year}/#{topic.slug}-#{topic.id}",
        )
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "records the draft on the blog with that blog's path format" do
        expect(result[:publication]).to have_attributes(
          blog_id: engineering.id,
          path: "/#{Time.current.year}/#{topic.slug}",
        )
      end
    end
  end
end
