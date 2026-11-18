# frozen_string_literal: true

RSpec.describe Blog::AddPublishersToPublicCategory do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:publishers, :group)
    fab!(:other_publishers, :group)
    fab!(:writers, :group)

    let(:dependencies) { {} }
    let(:full) { CategoryGroup.permission_types[:full] }
    let(:create_post) { CategoryGroup.permission_types[:create_post] }
    let(:readonly) { CategoryGroup.permission_types[:readonly] }

    # Publisher groups are set first: changing them updates an already stored category.
    before { SiteSetting.blog_publisher_groups = "#{publishers.id}|#{other_publishers.id}" }

    context "without a blog category" do
      it { is_expected.to fail_to_find_a_model(:category) }
    end

    context "when everyone can start topics in the blog category" do
      fab!(:blog_category, :category)

      before { SiteSetting.blog_category = blog_category.id }

      it "leaves it open without logging anything" do
        expect { result }.not_to change { UserHistory.count }
        expect(result).to run_successfully
        expect(blog_category.reload.category_groups).to be_empty
      end
    end

    context "when publisher groups lack full access" do
      fab!(:blog_category) do
        Fabricate(
          :category,
          permissions: {
            Group::AUTO_GROUPS[:everyone] => CategoryGroup.permission_types[:create_post],
            writers.id => CategoryGroup.permission_types[:readonly],
            publishers.id => CategoryGroup.permission_types[:create_post],
          },
        )
      end

      before { SiteSetting.blog_category = blog_category.id }

      it "grants them full access, keeps every other permission and logs the change" do
        expect(result).to run_successfully
        expect(blog_category.reload.category_groups.pluck(:group_id, :permission_type)).to(
          contain_exactly(
            [Group::AUTO_GROUPS[:everyone], create_post],
            [writers.id, readonly],
            [publishers.id, full],
            [other_publishers.id, full],
          ),
        )
        expect(
          UserHistory.where(
            action: UserHistory.actions[:custom_staff],
            custom_type: "blog_category_permissions",
            category_id: blog_category.id,
          ),
        ).to exist
      end
    end

    context "when publisher groups already have full access" do
      fab!(:blog_category) do
        Fabricate(
          :category,
          permissions: {
            writers.id => CategoryGroup.permission_types[:readonly],
            publishers.id => CategoryGroup.permission_types[:full],
            other_publishers.id => CategoryGroup.permission_types[:full],
          },
        )
      end

      before { SiteSetting.blog_category = blog_category.id }

      it "changes nothing" do
        expect { result }.not_to change {
          [
            UserHistory.count,
            blog_category.reload.category_groups.pluck(:group_id, :permission_type),
          ]
        }
        expect(result).to run_successfully
      end
    end
  end
end
