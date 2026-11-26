# frozen_string_literal: true

RSpec.describe Blog::Instance::Update do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:publishers, :group)
    fab!(:blog) do
      Blog::Instance.create!(
        name: "Engineering",
        slug: "engineering",
        description: "Notes from the team",
        published: false,
      )
    end

    let(:params) { { blog_id: blog.id, name: "Engineering notes", published: true } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before { SiteSetting.blog_publisher_groups = publishers.id.to_s }

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_manage_blogs) }
    end

    context "when the blog does not exist" do
      let(:params) { { blog_id: 0, name: "Missing" } }

      it { is_expected.to fail_to_find_a_model(:blog) }
    end

    context "when the change is invalid" do
      let(:params) { { blog_id: Blog::Instance.default_blog.id, published: false } }

      it "keeps the default blog published" do
        expect(result).to fail_with_an_invalid_model(:blog)
      end
    end

    context "when the category changes" do
      fab!(:category) { Fabricate(:category, permissions: { everyone: :readonly }) }

      let(:params) { { blog_id: blog.id, category_id: category.id } }

      it "lets publishers start topics in the new category" do
        result
        expect(category.reload.category_groups.pluck(:group_id)).to include(publishers.id)
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "saves only the fields that were sent" do
        expect(result[:blog].reload).to have_attributes(
          name: "Engineering notes",
          description: "Notes from the team",
          published: true,
        )
      end

      it "logs the change" do
        result
        expect(
          UserHistory.where(custom_type: "blog_update", acting_user_id: acting_user.id),
        ).to exist
      end
    end
  end
end
