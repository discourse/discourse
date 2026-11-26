# frozen_string_literal: true

RSpec.describe Blog::EnsureDraftsCategory do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:contributors, :group)
    fab!(:editors, :group)
    fab!(:publishers, :group)

    let(:dependencies) { {} }
    let(:full) { CategoryGroup.permission_types[:full] }
    let(:editorial_permissions) do
      [[contributors.id, full], [editors.id, full], [publishers.id, full]]
    end

    # Role groups are set first: changing them repairs an already stored category.
    before do
      SiteSetting.blog_contributor_groups = contributors.id.to_s
      SiteSetting.blog_editor_groups = "#{editors.id}|#{contributors.id}"
      SiteSetting.blog_publisher_groups = publishers.id.to_s
    end

    context "when the category is missing and creating it is disabled" do
      let(:dependencies) { { options: { create_missing: false } } }

      it "creates nothing" do
        expect { result }.not_to change { Category.count }
        expect(result).to fail_a_policy(:can_create_category)
        expect(SiteSetting.blog_drafts_category).to be_blank
      end
    end

    context "without a stored drafts category" do
      it "creates a private category for the editorial groups, stores it and logs it" do
        expect { result }.to change { Category.count }.by(1)
        expect(result).to run_successfully
        category = result[:category]
        expect(category).to have_attributes(
          name: "Blog drafts",
          user_id: Discourse.system_user.id,
          read_restricted: true,
        )
        expect(category.category_groups.pluck(:group_id, :permission_type)).to match_array(
          editorial_permissions,
        )
        expect(SiteSetting.blog_drafts_category.to_i).to eq(category.id)
        expect(category.topic.first_post.raw).to eq(I18n.t("blog.categories.drafts_description"))
        expect(
          UserHistory.where(
            action: UserHistory.actions[:create_category],
            category_id: category.id,
          ),
        ).to exist
        expect(UserHistory.where(custom_type: "blog_drafts_category_permissions")).not_to exist
      end
    end

    context "when a role setting still lists a deleted group" do
      before { editors.destroy! }

      it "leaves the deleted group out of the permissions" do
        expect(result[:category].category_groups.pluck(:group_id)).to contain_exactly(
          contributors.id,
          publishers.id,
        )
      end
    end

    context "when another process has stored a category this process has not seen yet" do
      fab!(:stored) { Fabricate(:private_category, group: contributors) }

      before do
        SiteSetting.provider.save(
          :blog_drafts_category,
          stored.id.to_s,
          SiteSetting.types[:category],
        )
      end

      it "uses the stored category instead of creating another" do
        expect { result }.not_to change { Category.count }
        expect(result[:category]).to eq(stored)
      end
    end

    context "when the default name is taken" do
      before { Fabricate(:category, name: "blog DRAFTS") }

      it "creates the category with the next free name" do
        expect(result).to run_successfully
        expect(result[:category].name).to eq("Blog drafts 2")
      end
    end

    context "when another category uses the default slug" do
      before { Fabricate(:category, slug: "blog-drafts") }

      it "creates the category with the next free slug" do
        expect(result).to run_successfully
        expect(result[:category]).to have_attributes(name: "Blog drafts", slug: "blog-drafts-2")
      end
    end

    context "when the stored drafts category was deleted" do
      before do
        deleted = Fabricate(:category)
        SiteSetting.blog_drafts_category = deleted.id
        deleted.destroy!
      end

      it "creates a new category and stores it" do
        expect { result }.to change { Category.count }.by(1)
        expect(result[:category]).to have_attributes(name: "Blog drafts", read_restricted: true)
        expect(SiteSetting.blog_drafts_category.to_i).to eq(result[:category].id)
      end
    end

    context "when the stored drafts category is the blog category" do
      fab!(:blog_category, :category)

      before do
        update_default_blog(category_id: blog_category.id)
        SiteSetting.blog_drafts_category = blog_category.id
      end

      it "creates a separate drafts category and leaves the blog category open" do
        expect { result }.to change { Category.count }.by(1)
        expect(result[:category]).not_to eq(blog_category)
        expect(SiteSetting.blog_drafts_category.to_i).to eq(result[:category].id)
        expect(blog_category.reload).to have_attributes(read_restricted: false)
        expect(blog_category.category_groups).to be_empty
      end
    end

    context "when the stored drafts category is the shared drafts category" do
      fab!(:shared_drafts, :category)

      before do
        SiteSetting.shared_drafts_category = shared_drafts.id
        SiteSetting.blog_drafts_category = shared_drafts.id
      end

      it "creates a separate drafts category and leaves the shared drafts category open" do
        expect { result }.to change { Category.count }.by(1)
        expect(result[:category]).not_to eq(shared_drafts)
        expect(SiteSetting.blog_drafts_category.to_i).to eq(result[:category].id)
        expect(shared_drafts.reload).to have_attributes(read_restricted: false)
        expect(shared_drafts.category_groups).to be_empty
      end
    end

    context "with a stored drafts category" do
      fab!(:drafts) do
        Fabricate(
          :category,
          permissions: {
            contributors.id => CategoryGroup.permission_types[:full],
            editors.id => CategoryGroup.permission_types[:full],
            publishers.id => CategoryGroup.permission_types[:full],
          },
        )
      end

      before { SiteSetting.blog_drafts_category = drafts.id }

      it "returns the category without creating or logging anything" do
        expect { result }.not_to change { [Category.count, UserHistory.count] }
        expect(result).to run_successfully
        expect(result[:category]).to eq(drafts)
      end
    end

    context "when the stored drafts category was opened to everyone" do
      fab!(:drafts) do
        Fabricate(
          :category,
          permissions: {
            Group::AUTO_GROUPS[:everyone] => CategoryGroup.permission_types[:readonly],
            contributors.id => CategoryGroup.permission_types[:full],
            editors.id => CategoryGroup.permission_types[:full],
            publishers.id => CategoryGroup.permission_types[:full],
          },
        )
      end

      before { SiteSetting.blog_drafts_category = drafts.id }

      it "refuses it and leaves the category as it is" do
        expect { result }.not_to change {
          [Category.count, drafts.reload.category_groups.pluck(:group_id).sort]
        }
        expect(result).to fail_a_policy(:category_private)
        expect(drafts).to have_attributes(read_restricted: false)
        expect(UserHistory.where(custom_type: "blog_drafts_category_permissions")).not_to exist
      end
    end

    context "when the stored drafts category grants an extra group access" do
      fab!(:outsiders, :group)
      fab!(:drafts) do
        Fabricate(
          :category,
          permissions: {
            contributors.id => CategoryGroup.permission_types[:full],
            editors.id => CategoryGroup.permission_types[:full],
            publishers.id => CategoryGroup.permission_types[:full],
            outsiders.id => CategoryGroup.permission_types[:readonly],
          },
        )
      end

      before { SiteSetting.blog_drafts_category = drafts.id }

      it "removes the extra group and logs the repair" do
        expect(result).to run_successfully
        expect(drafts.reload.category_groups.pluck(:group_id, :permission_type)).to match_array(
          editorial_permissions,
        )
        expect(
          UserHistory.where(
            action: UserHistory.actions[:custom_staff],
            custom_type: "blog_drafts_category_permissions",
            category_id: drafts.id,
          ),
        ).to exist
      end
    end
  end
end
