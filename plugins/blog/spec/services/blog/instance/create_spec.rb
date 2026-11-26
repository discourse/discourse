# frozen_string_literal: true

RSpec.describe Blog::Instance::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:slug) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:publishers, :group)

    let(:params) { { name: "Engineering", slug: "engineering" } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      enable_blog!
      SiteSetting.blog_publisher_groups = publishers.id.to_s
    end

    context "when the user is not an admin" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_manage_blogs) }
    end

    context "when the site has reached its limit of blogs" do
      before { SiteSetting.blog_max_instances = 1 }

      it { is_expected.to fail_a_policy(:can_add_blog) }
    end

    context "when the slug is taken" do
      let(:params) { super().merge(slug: "blog") }

      it { is_expected.to fail_with_an_invalid_model(:blog) }
    end

    context "with a chosen category" do
      fab!(:category) { Fabricate(:category, permissions: { everyone: :readonly }) }

      let(:params) { super().merge(category_id: category.id) }

      it "uses it and lets publishers start topics there" do
        expect { result }.not_to change { Category.count }
        expect(result[:blog].category_id).to eq(category.id)
        expect(category.reload.category_groups.pluck(:group_id)).to include(publishers.id)
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "adds an unpublished blog and leaves its category for the first article" do
        expect { result }.not_to change { Category.count }
        expect(result[:blog]).to have_attributes(
          name: "Engineering",
          published: false,
          category_id: nil,
        )
      end

      it "logs the creation" do
        result
        expect(
          UserHistory.where(custom_type: "blog_create", acting_user_id: acting_user.id),
        ).to exist
      end
    end
  end
end
