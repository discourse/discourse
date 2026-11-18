# frozen_string_literal: true

RSpec.describe Blog::EnsureDraftsCategory do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:contributors, :group)
    fab!(:editors, :group)
    fab!(:publishers, :group)

    let(:dependencies) { {} }
    let(:publisher_group_ids) { [publishers.id] }
    let(:full) { CategoryGroup.permission_types[:full] }
    let(:editorial_permissions) do
      [
        [contributors.id, full],
        [editors.id, full],
        *publisher_group_ids.map { |group_id| [group_id, full] },
      ]
    end

    # Role groups are set first: changing them repairs an already stored category.
    before do
      SiteSetting.blog_contributor_groups = contributors.id.to_s
      SiteSetting.blog_editor_groups = "#{editors.id}|#{contributors.id}"
      SiteSetting.blog_publisher_groups = publisher_group_ids.join("|")
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
      it { is_expected.to run_successfully }

      it "creates a private category for the editorial groups and stores it" do
        expect { result }.to change { Category.count }.by(1)
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
      end

      it "logs the creation without a permissions repair" do
        result
        expect(
          UserHistory.where(
            action: UserHistory.actions[:create_category],
            category_id: result[:category].id,
          ),
        ).to exist
        expect(UserHistory.where(custom_type: "blog_drafts_category_permissions")).not_to exist
      end

      it "reuses the stored category on the next call" do
        result
        expect { described_class.call }.not_to change { Category.count }
        expect(described_class.call[:category]).to eq(result[:category])
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
        SiteSetting.blog_category = blog_category.id
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

      it { is_expected.to run_successfully }

      it "returns the category without creating or logging anything" do
        expect { result }.not_to change { [Category.count, UserHistory.count] }
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

      it "restricts it to the editorial groups again and logs the repair" do
        expect(result).to run_successfully
        drafts.reload
        expect(drafts.read_restricted).to eq(true)
        expect(drafts.category_groups.pluck(:group_id, :permission_type)).to match_array(
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
        expect(UserHistory.where(custom_type: "blog_drafts_category_permissions")).to exist
      end
    end

    context "when the publisher groups have changed" do
      fab!(:new_publishers, :group)
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

      let(:publisher_group_ids) { [new_publishers.id] }

      before { SiteSetting.blog_drafts_category = drafts.id }

      it "replaces the old publishers with the new ones" do
        expect(result).to run_successfully
        expect(drafts.reload.category_groups.pluck(:group_id, :permission_type)).to match_array(
          [[contributors.id, full], [editors.id, full], [new_publishers.id, full]],
        )
        expect(UserHistory.where(custom_type: "blog_drafts_category_permissions")).to exist
      end
    end
  end
end
