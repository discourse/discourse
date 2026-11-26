# frozen_string_literal: true

RSpec.describe Blog::EnsurePublicCategory do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:blog_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params: { blog_id: blog.id }, **dependencies) }

    fab!(:publishers, :group)

    let(:blog) { Blog::Instance.default_blog }
    let(:dependencies) { {} }

    before { SiteSetting.blog_publisher_groups = publishers.id.to_s }

    context "with a chosen blog category" do
      fab!(:writers, :group)
      fab!(:blog_category) do
        Fabricate(:category, permissions: { writers.id => CategoryGroup.permission_types[:full] })
      end

      before { update_default_blog(category_id: blog_category.id) }

      it "returns it without changing its permissions or logging anything" do
        expect { result }.not_to change { [Category.count, UserHistory.count] }
        expect(result).to run_successfully
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
        expect(Blog::Instance.default_blog.category_id).to be_blank
      end
    end

    context "without a blog category" do
      it "creates an open category where publishers have full access, stores it and logs it" do
        expect { result }.to change { Category.count }.by(1)
        expect(result).to run_successfully
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
        expect(Blog::Instance.default_blog.category_id.to_i).to eq(category.id)
        expect(blog.reload.category_id).to eq(category.id)
        expect(category.topic.first_post.raw).to eq(I18n.t("blog.categories.public_description"))
        expect(
          UserHistory.where(
            action: UserHistory.actions[:create_category],
            category_id: category.id,
          ),
        ).to exist
      end

      it "leaves deleted publisher groups out of the permissions" do
        SiteSetting.blog_publisher_groups =
          "#{publishers.id}|#{Fabricate(:group).tap(&:destroy!).id}"

        expect(result[:category].category_groups.pluck(:group_id)).to contain_exactly(
          Group::AUTO_GROUPS[:everyone],
          publishers.id,
        )
      end
    end

    context "with a blog other than the default" do
      let(:blog) { Blog::Instance.create!(name: "Engineering notes", slug: "engineering") }

      it "names the category after the blog and stores it on the blog only" do
        expect(result).to run_successfully
        expect(result[:category]).to have_attributes(
          name: "Engineering notes Blog",
          slug: "engineering-notes-blog",
        )
        expect(blog.reload.category_id).to eq(result[:category].id)
        expect(Blog::Instance.default_blog.category_id).to be_blank
      end

      context "when the blog's name already ends with the word" do
        let(:blog) { Blog::Instance.create!(name: "Design blog", slug: "design") }

        it "does not repeat it" do
          expect(result[:category]).to have_attributes(name: "Design blog", slug: "design-blog")
        end
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
        update_default_blog(category_id: deleted.id)
        deleted.destroy!
      end

      it "creates a new category and stores it" do
        expect { result }.to change { Category.count }.by(1)
        expect(result[:category].name).to eq("Blog")
        expect(Blog::Instance.default_blog.category_id.to_i).to eq(result[:category].id)
      end
    end
  end
end
