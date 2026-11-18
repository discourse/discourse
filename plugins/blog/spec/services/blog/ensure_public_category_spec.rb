# frozen_string_literal: true

RSpec.describe Blog::EnsurePublicCategory do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:publishers, :group)

    let(:dependencies) { {} }

    before { SiteSetting.blog_publisher_groups = publishers.id.to_s }

    context "with a chosen blog category" do
      fab!(:writers, :group)
      fab!(:blog_category) do
        Fabricate(:category, permissions: { writers.id => CategoryGroup.permission_types[:full] })
      end

      before { SiteSetting.blog_category = blog_category.id }

      it { is_expected.to run_successfully }

      it "returns it without changing its permissions or logging anything" do
        expect { result }.not_to change { [Category.count, UserHistory.count] }
        expect(result[:category]).to eq(blog_category)
        expect(blog_category.reload.category_groups.pluck(:group_id, :permission_type)).to eq(
          [[writers.id, CategoryGroup.permission_types[:full]]],
        )
      end
    end

    context "when a top-level category already uses the default name" do
      before { Fabricate(:category, name: "BLOG") }

      it "creates nothing" do
        expect { result }.not_to change { Category.count }
        expect(result).to fail_a_policy(:name_available)
        expect(SiteSetting.blog_category).to be_blank
      end
    end

    context "without a blog category" do
      it { is_expected.to run_successfully }

      it "creates an open category where publishers have full access and stores it" do
        expect { result }.to change { Category.count }.by(1)
        category = result[:category]
        expect(category).to have_attributes(
          name: "Blog",
          user_id: Discourse.system_user.id,
          read_restricted: false,
        )
        expect(category.category_groups.pluck(:group_id, :permission_type)).to contain_exactly(
          [Group::AUTO_GROUPS[:everyone], CategoryGroup.permission_types[:create_post]],
          [publishers.id, CategoryGroup.permission_types[:full]],
        )
        expect(SiteSetting.blog_category.to_i).to eq(category.id)
      end

      it "explains what the category holds" do
        expect(result[:category].topic.first_post.raw).to eq(
          I18n.t("blog.categories.public_description"),
        )
      end

      it "leaves deleted publisher groups out of the permissions" do
        SiteSetting.blog_publisher_groups =
          "#{publishers.id}|#{Fabricate(:group).tap(&:destroy!).id}"

        expect(result[:category].category_groups.pluck(:group_id)).to contain_exactly(
          Group::AUTO_GROUPS[:everyone],
          publishers.id,
        )
      end

      it "logs the creation" do
        result
        expect(
          UserHistory.where(
            action: UserHistory.actions[:create_category],
            category_id: result[:category].id,
          ),
        ).to exist
      end

      it "reuses the stored category on the next call" do
        result
        expect { described_class.call }.not_to change { Category.count }
        expect(described_class.call[:category]).to eq(result[:category])
      end
    end

    context "when another category uses the default slug" do
      before { Fabricate(:category, slug: "blog") }

      it "creates the category with the next free slug" do
        expect(result).to run_successfully
        expect(result[:category]).to have_attributes(name: "Blog", slug: "blog-2")
      end
    end

    context "when the stored blog category was deleted" do
      before do
        deleted = Fabricate(:category)
        SiteSetting.blog_category = deleted.id
        deleted.destroy!
      end

      it "creates a new category and stores it" do
        expect { result }.to change { Category.count }.by(1)
        expect(result[:category].name).to eq("Blog")
        expect(SiteSetting.blog_category.to_i).to eq(result[:category].id)
      end
    end
  end
end
