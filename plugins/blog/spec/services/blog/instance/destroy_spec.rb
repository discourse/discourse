# frozen_string_literal: true

RSpec.describe Blog::Instance::Destroy do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:category)
    fab!(:blog) { Blog::Instance.create!(name: "Engineering", slug: "engineering", category:) }

    let(:params) { { blog_id: blog.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_manage_blogs) }
    end

    context "when the blog is the default blog" do
      let(:params) { { blog_id: Blog::Instance.default_blog.id } }

      it { is_expected.to fail_a_policy(:not_default) }
    end

    context "when the blog has articles" do
      before { Blog::Publication.create!(topic: Fabricate(:topic), blog:, path: "/story") }

      it { is_expected.to fail_a_policy(:no_articles) }
    end

    context "when everything's ok" do
      it "deletes the blog, keeps its category and logs it" do
        expect(result).to run_successfully
        expect(Blog::Instance.exists?(blog.id)).to eq(false)
        expect(category.reload).to be_present
        expect(UserHistory.where(custom_type: "blog_destroy")).to exist
      end
    end
  end
end
