# encoding: utf-8
# frozen_string_literal: true

RSpec.describe Category do
  fab!(:user)

  it_behaves_like "it has custom fields"

  it { is_expected.to validate_presence_of :user_id }
  it { is_expected.to validate_presence_of :name }

  it do
    is_expected.to validate_numericality_of(:default_slow_mode_seconds).is_greater_than(
      0,
    ).only_integer
  end

  it "validates uniqueness of name" do
    Fabricate(:category_with_definition)
    is_expected.to validate_uniqueness_of(:name).scoped_to(:parent_category_id).case_insensitive
  end

  it "validates inclusion of search_priority" do
    category = Fabricate.build(:category, user: user)

    expect(category.valid?).to eq(true)

    category.search_priority = Searchable::PRIORITIES.values.last + 1

    expect(category.valid?).to eq(false)
    expect(category.errors.to_hash.keys).to contain_exactly(:search_priority)
  end

  it "validates uniqueness in case insensitive way" do
    Fabricate(:category_with_definition, name: "Cats")
    cats = Fabricate.build(:category, name: "cats")
    expect(cats).to_not be_valid
    expect(cats.errors[:name]).to be_present
  end

  describe "Associations" do
    it { is_expected.to have_one(:category_setting).dependent(:destroy) }

    it "automatically creates a category setting" do
      expect { Fabricate(:category) }.to change { CategorySetting.count }.by(1)
    end

    it "should delete associated sidebar_section_links when category is destroyed" do
      category_sidebar_section_link = Fabricate(:category_sidebar_section_link)
      category_sidebar_section_link_2 =
        Fabricate(:category_sidebar_section_link, linkable: category_sidebar_section_link.linkable)

      expect { category_sidebar_section_link.linkable.destroy! }.to change {
        SidebarSectionLink.count
      }.from(12).to(10)
      expect(
        SidebarSectionLink.where(
          id: [category_sidebar_section_link.id, category_sidebar_section_link_2.id],
        ).count,
      ).to eq(0)
    end
  end

  describe "slug" do
    it "converts to lower" do
      category = Category.create!(name: "Hello World", slug: "Hello-World", user: user)
      expect(category.slug).to eq("hello-world")
    end
  end

  describe "resolve_permissions" do
    it "can determine read_restricted" do
      read_restricted, resolved = Category.resolve_permissions(everyone: :full)

      expect(read_restricted).to be false
      expect(resolved).to be_blank
    end
  end

  describe "permissions_params" do
    it "returns the right group names and permission type" do
      category = Fabricate(:category_with_definition)
      group = Fabricate(:group)
      category_group = Fabricate(:category_group, category: category, group: group)
      expect(category.permissions_params).to eq("#{group.name}" => category_group.permission_type)
    end
  end

  describe "#category_moderation_groups" do
    fab!(:group)
    fab!(:category) { Fabricate(:category_with_definition) }
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:category_moderation_group) { Fabricate(:category_moderation_group, category:, group:) }
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

    it "is destroyed if the group is destroyed" do
      expect(category.category_moderation_groups).to contain_exactly(category_moderation_group)
      reviewable = PostActionCreator.spam(user, post).reviewable
      group.destroy
      expect(category.reload.category_moderation_groups).to be_blank
    end
  end

  describe "topic_create_allowed and post_create_allowed" do
    fab!(:group)

    fab!(:user) do
      user = Fabricate(:user)
      group.add(user)
      group.save
      user
    end

    fab!(:admin)

    fab!(:default_category) { Fabricate(:category_with_definition) }

    fab!(:full_category) do
      c = Fabricate(:category_with_definition)
      c.set_permissions(group => :full)
      c.save
      c
    end

    fab!(:can_post_category) do
      c = Fabricate(:category_with_definition)
      c.set_permissions(group => :create_post)
      c.save
      c
    end

    fab!(:can_read_category) do
      c = Fabricate(:category_with_definition)
      c.set_permissions(group => :readonly)
      c.save
    end

    let(:user_guardian) { Guardian.new(user) }
    let(:admin_guardian) { Guardian.new(admin) }
    let(:anon_guardian) { Guardian.new(nil) }

    context "when disabling uncategorized" do
      before { SiteSetting.allow_uncategorized_topics = false }

      it "allows everything to admins unconditionally" do
        count = Category.count

        expect(Category.topic_create_allowed(admin_guardian).count).to eq(count)
        expect(Category.post_create_allowed(admin_guardian).count).to eq(count)
        expect(Category.secured(admin_guardian).count).to eq(count)
      end

      it "allows normal users correct access to all categories" do
        # Sam: I am mixed here, once disabling uncategorized maybe users should no
        # longer be allowed to know about it so all counts should go down?
        expect(Category.secured(user_guardian).count).to eq(5)
        expect(Category.post_create_allowed(user_guardian).count).to eq(4)
        expect(Category.topic_create_allowed(user_guardian).count).to eq(2)
      end
    end

    it "allows everything to admins unconditionally" do
      count = Category.count

      expect(Category.topic_create_allowed(admin_guardian).count).to eq(count)
      expect(Category.post_create_allowed(admin_guardian).count).to eq(count)
      expect(Category.secured(admin_guardian).count).to eq(count)
    end

    it "allows normal users correct access to all categories" do
      expect(Category.secured(user_guardian).count).to eq(5)
      expect(Category.post_create_allowed(user_guardian).count).to eq(4)
      expect(Category.topic_create_allowed(user_guardian).count).to eq(3)
    end

    it "allows anon correct access" do
      expect(Category.scoped_to_permissions(anon_guardian, [:readonly]).count).to eq(2)
      expect(Category.post_create_allowed(anon_guardian).count).to eq(0)
      expect(Category.topic_create_allowed(anon_guardian).count).to eq(0)

      # nil has special semantics
      expect(Category.scoped_to_permissions(nil, [:readonly]).count).to eq(2)
    end

    it "handles :everyone scope" do
      can_post_category.set_permissions(everyone: :create_post)
      can_post_category.save

      expect(Category.post_create_allowed(user_guardian).count).to eq(4)

      # anonymous has permission to create no topics
      expect(Category.scoped_to_permissions(user_guardian, [:readonly]).count).to eq(3)
    end
  end

  describe "with_parents" do
    fab!(:category)
    fab!(:subcategory) { Fabricate(:category, parent_category: category) }

    it "returns parent categories and subcategories" do
      expect(Category.with_parents([category.id])).to contain_exactly(category)
    end

    it "returns only categories if top-level categories" do
      expect(Category.with_parents([subcategory.id])).to contain_exactly(category, subcategory)
    end
  end

  describe "security" do
    fab!(:category) { Fabricate(:category_with_definition) }
    fab!(:category_2) { Fabricate(:category_with_definition) }
    fab!(:user)
    fab!(:group)

    it "secures categories correctly" do
      expect(category.read_restricted?).to be false

      category.set_permissions({})
      expect(category.read_restricted?).to be true

      category.set_permissions(everyone: :full)
      expect(category.read_restricted?).to be false

      expect(user.secure_categories).to be_empty

      group.add(user)
      group.save

      category.set_permissions(group.id => :full)
      category.save

      user.reload
      expect(user.secure_categories).to eq([category])
    end

    it "lists all secured categories correctly" do
      uncategorized = Category.find(SiteSetting.uncategorized_category_id)

      group.add(user)
      category.set_permissions(group.id => :full)
      category.save!
      category_2.set_permissions(group.id => :full)
      category_2.save!

      expect(Category.secured).to match_array([uncategorized])
      expect(Category.secured(Guardian.new(user))).to match_array(
        [uncategorized, category, category_2],
      )
    end
  end

  it "strips leading blanks" do
    expect(Fabricate(:category_with_definition, name: " music").name).to eq("music")
  end

  it "strips trailing blanks" do
    expect(Fabricate(:category_with_definition, name: "bugs ").name).to eq("bugs")
  end

  it "strips leading and trailing blanks" do
    expect(Fabricate(:category_with_definition, name: "  blanks ").name).to eq("blanks")
  end

  it "sets name_lower" do
    expect(Fabricate(:category_with_definition, name: "Not MySQL").name_lower).to eq("not mysql")
  end

  it "has custom fields" do
    category = Fabricate(:category_with_definition, name: " music")
    expect(category.custom_fields["a"]).to be_nil

    category.custom_fields["bob"] = "marley"
    category.custom_fields["jack"] = "black"
    category.save

    category = Category.find(category.id)
    expect(category.custom_fields).to eq("bob" => "marley", "jack" => "black")
  end

  describe "short name" do
    fab!(:category) { Fabricate(:category_with_definition, name: "xx") }

    it "creates the category" do
      expect(category).to be_present
    end

    it "has one topic" do
      expect(Topic.where(category_id: category.id).count).to eq(1)
    end
  end

  describe "non-english characters" do
    context "when using ascii slug generator" do
      before do
        SiteSetting.slug_generation_method = "ascii"
        @category = Fabricate(:category_with_definition, name: "测试")
      end
      after { @category.destroy }

      it "creates a blank slug" do
        expect(@category.slug).to be_blank
        expect(@category.slug_for_url).to eq("#{@category.id}-category")
      end
    end

    context "when using none slug generator" do
      before do
        SiteSetting.slug_generation_method = "none"
        @category = Fabricate(:category_with_definition, name: "测试")
      end
      after do
        SiteSetting.slug_generation_method = "ascii"
        @category.destroy
      end

      it "creates a blank slug" do
        expect(@category.slug).to be_blank
        expect(@category.slug_for_url).to eq("#{@category.id}-category")
      end
    end

    context "when using encoded slug generator" do
      before do
        SiteSetting.slug_generation_method = "encoded"
        @category = Fabricate(:category_with_definition, name: "测试")
      end
      after do
        SiteSetting.slug_generation_method = "ascii"
        @category.destroy
      end

      it "creates a slug" do
        expect(@category.slug).to eq("%E6%B5%8B%E8%AF%95")
        expect(@category.slug_for_url).to eq("%E6%B5%8B%E8%AF%95")
      end

      it "keeps the encoded slug after saving" do
        @category.save
        expect(@category.slug).to eq("%E6%B5%8B%E8%AF%95")
        expect(@category.slug_for_url).to eq("%E6%B5%8B%E8%AF%95")
      end
    end
  end

  describe "slug would be a number" do
    let(:category) { Fabricate.build(:category, name: "2") }

    it "creates a blank slug" do
      expect(category.slug).to be_blank
      expect(category.slug_for_url).to eq("#{category.id}-category")
    end
  end

  describe "custom slug can be provided" do
    it "can be sanitized" do
      @c = Fabricate(:category_with_definition, name: "Fun Cats", slug: "fun-cats")
      @cat = Fabricate(:category_with_definition, name: "love cats", slug: "love-cats")

      @c.slug = "  invalid slug"
      @c.save
      expect(@c.slug).to eq("invalid-slug")

      c = Fabricate.build(:category, name: "More Fun Cats", slug: "love-cats")
      expect(c).not_to be_valid
      expect(c.errors[:slug]).to be_present

      @cat.slug = "#{@c.id}-category"
      expect(@cat).not_to be_valid
      expect(@cat.errors[:slug]).to be_present

      @cat.slug = "#{@cat.id}-category"
      expect(@cat).to be_valid
      expect(@cat.errors[:slug]).not_to be_present
    end

    context "if SiteSettings.slug_generation_method = ascii" do
      before { SiteSetting.slug_generation_method = "ascii" }

      it "fails if slug contains non-ascii characters" do
        c = Fabricate.build(:category, name: "Sem acentuação", slug: "sem-acentuação")
        expect(c).not_to be_valid

        expect(c.errors[:slug]).to be_present
      end
    end
  end

  describe "description_text" do
    it "correctly generates text description as needed" do
      c = Category.new
      expect(c.description_text).to be_nil
      c.description = "&lt;hello <a>foo/bar</a>."
      expect(c.description_text).to eq("&lt;hello foo/bar.")
    end
  end

  describe "after create" do
    before do
      @category = Fabricate(:category_with_definition, name: "Amazing Category")
      @topic = @category.topic
    end

    it "is created correctly" do
      expect(@category.slug).to eq("amazing-category")
      expect(@category.slug_for_url).to eq(@category.slug)

      expect(@category.description).to be_blank

      expect(Topic.where(category_id: @category).count).to eq(1)

      expect(@topic).to be_present

      expect(@topic.category).to eq(@category)

      expect(@topic).to be_visible

      expect(@topic.pinned_at).to be_present

      expect(Guardian.new(@category.user).can_delete?(@topic)).to be false

      expect(@topic.posts.count).to eq(1)

      expect(@category.topic_url).to be_present

      expect(@category.posts_week).to eq(0)
      expect(@category.posts_month).to eq(0)
      expect(@category.posts_year).to eq(0)

      expect(@category.topics_week).to eq(0)
      expect(@category.topics_month).to eq(0)
      expect(@category.topics_year).to eq(0)
    end

    it "cooks the definition" do
      category =
        Category.create(
          name: "little-test",
          user_id: Discourse.system_user.id,
          description: "click the link [here](https://fakeurl.com)",
        )
      expect(category.description.include?("[here]")).to eq(false)
      expect(category.description).to eq(category.topic.first_post.cooked)
    end

    it "renames the definition when renamed" do
      @category.update(name: "Troutfishing")
      @topic.reload
      expect(@topic.title).to match(/Troutfishing/)
      expect(@topic.fancy_title).to match(/Troutfishing/)
    end

    it "doesn't raise an error if there is no definition topic to rename (uncategorized)" do
      expect { @category.update(name: "Troutfishing", topic_id: nil) }.to_not raise_error
    end

    it "creates permalink when category slug is changed" do
      @category.update(slug: "new-category")
      expect(Permalink.count).to eq(1)
    end

    it "reuses existing permalink when category slug is changed" do
      permalink = Permalink.create!(url: "c/#{@category.slug}/#{@category.id}", category_id: 42)

      expect { @category.update(slug: "new-slug") }.to_not change { Permalink.count }
      expect(permalink.reload.category_id).to eq(@category.id)
    end

    it "creates permalink when sub category slug is changed" do
      sub_category =
        Fabricate(:category_with_definition, slug: "sub-category", parent_category_id: @category.id)
      sub_category.update(slug: "new-sub-category")
      expect(Permalink.count).to eq(1)
    end

    it "deletes permalink when category slug is reused" do
      Fabricate(:permalink, url: "/c/bikeshed-category", category_id: 42)
      Fabricate(:category_with_definition, slug: "bikeshed-category")
      expect(Permalink.count).to eq(0)
    end

    it "deletes permalink when sub category slug is reused" do
      Fabricate(:permalink, url: "/c/main-category/sub-category", category_id: 42)
      main_category = Fabricate(:category_with_definition, slug: "main-category")
      Fabricate(
        :category_with_definition,
        slug: "sub-category",
        parent_category_id: main_category.id,
      )
      expect(Permalink.count).to eq(0)
    end

    it "correctly creates permalink when category slug is changed in subfolder install" do
      set_subfolder "/forum"
      old_url = @category.url
      @category.update(slug: "new-category")
      permalink = Permalink.last
      expect(permalink.url).to eq(old_url[1..-1])
    end

    it "should not set its description topic to auto-close" do
      category = Fabricate(:category_with_definition, name: "Closing Topics", auto_close_hours: 1)
      expect(category.topic.public_topic_timer).to eq(nil)
    end

    describe "creating a new category with the same slug" do
      it "should have a blank slug if at the same level" do
        category = Fabricate(:category_with_definition, name: "Amazing Categóry")
        expect(category.slug).to be_blank
        expect(category.slug_for_url).to eq("#{category.id}-category")
      end

      it "doesn't have a blank slug if not at the same level" do
        parent = Fabricate(:category_with_definition, name: "Other parent")
        category =
          Fabricate(
            :category_with_definition,
            name: "Amazing Categóry",
            parent_category_id: parent.id,
          )
        expect(category.slug).to eq("amazing-category")
        expect(category.slug_for_url).to eq("amazing-category")
      end
    end

    describe "trying to change the category topic's category" do
      before do
        @new_cat = Fabricate(:category_with_definition, name: "2nd Category", user: @category.user)
        @topic.change_category_to_id(@new_cat.id)
        @topic.reload
        @category.reload
      end

      it "does not cause changes" do
        expect(@category.topic_count).to eq(0)
        expect(@topic.category).to eq(@category)
        expect(@category.topic).to eq(@topic)
      end
    end
  end

  describe "new" do
    subject(:category) { Fabricate.build(:category, user: Fabricate(:user)) }

    it "triggers a extensibility event" do
      event = DiscourseEvent.track_events { category.save! }.last

      expect(event[:event_name]).to eq(:category_created)
      expect(event[:params].first).to eq(category)
    end
  end

  describe "update" do
    it "should enforce uniqueness of slug" do
      Fabricate(:category_with_definition, slug: "the-slug")
      c2 = Fabricate(:category_with_definition, slug: "different-slug")
      c2.slug = "the-slug"
      expect(c2).to_not be_valid
      expect(c2.errors[:slug]).to be_present
    end
  end

  describe "destroy" do
    before do
      @category = Fabricate(:category_with_definition)
      @category_id = @category.id
      @topic_id = @category.topic_id
      SiteSetting.shared_drafts_category = @category.id.to_s
    end

    it "is deleted correctly" do
      @category.destroy
      expect(Category.exists?(id: @category_id)).to be false
      expect(Topic.with_deleted.where.not(deleted_at: nil).exists?(id: @topic_id)).to be true
      expect(SiteSetting.shared_drafts_category).to be_blank
    end

    it "deletes related embeddable host" do
      embeddable_host = Fabricate(:embeddable_host, category: @category)
      @category.destroy!
      expect { embeddable_host.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "triggers a extensibility event" do
      event = DiscourseEvent.track(:category_destroyed) { @category.destroy }

      expect(event[:event_name]).to eq(:category_destroyed)
      expect(event[:params].first).to eq(@category)
    end
  end

  describe "latest" do
    it "should be updated correctly" do
      category = freeze_time(1.minute.ago) { Fabricate(:category_with_definition) }
      post = create_post(category: category.id, created_at: 15.seconds.ago)

      category.reload
      expect(category.latest_post_id).to eq(post.id)
      expect(category.latest_topic_id).to eq(post.topic_id)

      post2 = create_post(category: category.id, created_at: 10.seconds.ago)
      post3 = create_post(topic_id: post.topic_id, category: category.id, created_at: 5.seconds.ago)

      category.reload
      expect(category.latest_post_id).to eq(post3.id)
      expect(category.latest_topic_id).to eq(post2.topic_id)

      post3.reload

      destroyer = PostDestroyer.new(Fabricate(:admin), post3)
      destroyer.destroy

      category.reload
      expect(category.latest_post_id).to eq(post2.id)
    end
  end

  describe "update_stats" do
    before do
      @category =
        Fabricate(:category_with_definition, user: Fabricate(:user, refresh_auto_groups: true))
    end

    context "with regular topics" do
      before do
        create_post(user: @category.user, category: @category.id)
        Category.update_stats
        @category.reload
      end

      it "updates topic stats" do
        expect(@category.topics_week).to eq(1)
        expect(@category.topics_month).to eq(1)
        expect(@category.topics_year).to eq(1)
        expect(@category.topic_count).to eq(1)
        expect(@category.post_count).to eq(1)
        expect(@category.posts_year).to eq(1)
        expect(@category.posts_month).to eq(1)
        expect(@category.posts_week).to eq(1)
      end
    end

    context "with deleted topics" do
      before do
        @category.topics << Fabricate(:deleted_topic, user: @category.user)
        Category.update_stats
        @category.reload
      end

      it "does not count deleted topics" do
        expect(@category.topics_week).to eq(0)
        expect(@category.topic_count).to eq(0)
        expect(@category.topics_month).to eq(0)
        expect(@category.topics_year).to eq(0)
        expect(@category.post_count).to eq(0)
        expect(@category.posts_year).to eq(0)
        expect(@category.posts_month).to eq(0)
        expect(@category.posts_week).to eq(0)
      end
    end

    context "with revised post" do
      before do
        post = create_post(user: @category.user, category: @category.id)

        SiteSetting.editing_grace_period = 1.minute
        post.revise(post.user, { raw: "updated body" }, revised_at: post.updated_at + 2.minutes)

        Category.update_stats
        @category.reload
      end

      it "doesn't count each version of a post" do
        expect(@category.post_count).to eq(1)
        expect(@category.posts_year).to eq(1)
        expect(@category.posts_month).to eq(1)
        expect(@category.posts_week).to eq(1)
      end
    end

    context "for uncategorized category" do
      before do
        @uncategorized = Category.find(SiteSetting.uncategorized_category_id)
        create_post(user: Fabricate(:user, refresh_auto_groups: true), category: @uncategorized.id)
        Category.update_stats
        @uncategorized.reload
      end

      it "updates topic stats" do
        expect(@uncategorized.topics_week).to eq(1)
        expect(@uncategorized.topics_month).to eq(1)
        expect(@uncategorized.topics_year).to eq(1)
        expect(@uncategorized.topic_count).to eq(1)
        expect(@uncategorized.post_count).to eq(1)
        expect(@uncategorized.posts_year).to eq(1)
        expect(@uncategorized.posts_month).to eq(1)
        expect(@uncategorized.posts_week).to eq(1)
      end
    end

    context "when there are no topics left" do
      let!(:topic) { create_post(user: @category.user, category: @category.id).reload.topic }

      it "can update the topic count to zero" do
        @category.reload
        expect(@category.topic_count).to eq(1)
        expect(@category.topics.count).to eq(2)
        topic.delete # Delete so the post trash/destroy hook doesn't fire

        Category.update_stats
        @category.reload
        expect(@category.topics.count).to eq(1)
        expect(@category.topic_count).to eq(0)
      end
    end
  end

  describe "#url" do
    before_all { SiteSetting.max_category_nesting = 3 }

    fab!(:category) { Fabricate(:category, name: "root") }

    fab!(:sub_category) { Fabricate(:category, name: "child", parent_category_id: category.id) }

    fab!(:sub_sub_category) do
      Fabricate(:category, name: "child_of_child", parent_category_id: sub_category.id)
    end

    describe "for normal categories" do
      it "builds a url" do
        expect(category.url).to eq("/c/root/#{category.id}")
      end
    end

    describe "for subcategories" do
      it "builds a url" do
        expect(sub_category.url).to eq("/c/root/child/#{sub_category.id}")
      end
    end

    describe "for sub-sub-categories" do
      it "builds a url" do
        expect(sub_sub_category.url).to eq("/c/root/child/child-of-child/#{sub_sub_category.id}")
      end
    end
  end

  describe "uncategorized" do
    let(:cat) { Category.where(id: SiteSetting.uncategorized_category_id).first }

    it "reports as `uncategorized?`" do
      expect(cat).to be_uncategorized
    end

    it "cannot have a parent category" do
      cat.parent_category_id = Fabricate(:category_with_definition).id
      expect(cat).to_not be_valid
    end
  end

  describe "parent categories" do
    fab!(:user)
    fab!(:parent_category) { Fabricate(:category_with_definition, user: user) }

    it "can be associated with a parent category" do
      sub_category = Fabricate.build(:category, parent_category_id: parent_category.id, user: user)
      expect(sub_category).to be_valid
      expect(sub_category.parent_category).to eq(parent_category)
    end

    it "cannot associate a category with itself" do
      category = Fabricate(:category_with_definition, user: user)
      category.parent_category_id = category.id
      expect(category).to_not be_valid
    end

    it "cannot have a category two levels deep" do
      sub_category =
        Fabricate(:category_with_definition, parent_category_id: parent_category.id, user: user)
      nested_sub_category =
        Fabricate.build(:category, parent_category_id: sub_category.id, user: user)
      expect(nested_sub_category).to_not be_valid
    end

    describe ".query_parent_category" do
      it "should return the parent category id given a parent slug" do
        parent_category.name = "Amazing Category"
        expect(parent_category.id).to eq(Category.query_parent_category(parent_category.slug))
      end
    end

    describe ".query_category" do
      it "should return the category" do
        category =
          Fabricate(
            :category_with_definition,
            name: "Amazing Category",
            parent_category_id: parent_category.id,
            user: user,
          )
        parent_category.name = "Amazing Parent Category"
        expect(category).to eq(Category.query_category(category.slug, parent_category.id))
      end
    end
  end

  describe "find_by_email" do
    it "is case insensitive" do
      c1 = Fabricate(:category_with_definition, email_in: "lower@example.com")
      c2 = Fabricate(:category_with_definition, email_in: "UPPER@EXAMPLE.COM")
      c3 = Fabricate(:category_with_definition, email_in: "Mixed.Case@Example.COM")
      expect(Category.find_by_email("LOWER@EXAMPLE.COM")).to eq(c1)
      expect(Category.find_by_email("upper@example.com")).to eq(c2)
      expect(Category.find_by_email("mixed.case@example.com")).to eq(c3)
      expect(Category.find_by_email("MIXED.CASE@EXAMPLE.COM")).to eq(c3)
    end
  end

  describe "find_by_slug" do
    fab!(:category) { Fabricate(:category_with_definition, slug: "awesome-category") }

    fab!(:subcategory) do
      Fabricate(
        :category_with_definition,
        parent_category_id: category.id,
        slug: "awesome-sub-category",
      )
    end

    it "finds a category that exists" do
      expect(Category.find_by_slug("awesome-category")).to eq(category)
    end

    it "finds a subcategory that exists" do
      expect(Category.find_by_slug("awesome-sub-category", "awesome-category")).to eq(subcategory)
    end

    it "produces nil if the parent doesn't exist" do
      expect(Category.find_by_slug("awesome-sub-category", "no-such-category")).to eq(nil)
    end

    it "produces nil if the parent doesn't exist and the requested category is a root category" do
      expect(Category.find_by_slug("awesome-category", "no-such-category")).to eq(nil)
    end

    it "produces nil if the subcategory doesn't exist" do
      expect(Category.find_by_slug("no-such-category", "awesome-category")).to eq(nil)
    end
  end

  describe "validate email_in" do
    fab!(:user)

    it "works with a valid email" do
      expect(Category.new(name: "test", user: user, email_in: "test@example.com").valid?).to eq(
        true,
      )
    end

    it "adds an error with an invalid email" do
      category = Category.new(name: "test", user: user, email_in: "<sup>test</sup>")
      expect(category.valid?).to eq(false)
      expect(category.errors.full_messages.join).not_to match(/<sup>/)
    end

    context "with a duplicate email in a group" do
      fab!(:group) { Fabricate(:group, name: "testgroup", incoming_email: "test@example.com") }

      it "adds an error with an invalid email" do
        category = Category.new(name: "test", user: user, email_in: group.incoming_email)
        expect(category.valid?).to eq(false)
      end
    end

    context "with duplicate email in a category" do
      fab!(:category) do
        Fabricate(
          :category_with_definition,
          user: user,
          name: "<b>cool</b>",
          email_in: "test@example.com",
        )
      end

      it "adds an error with an invalid email" do
        category = Category.new(name: "test", user: user, email_in: "test@example.com")
        expect(category.valid?).to eq(false)
        expect(category.errors.full_messages.join).not_to match(/<b>/)
      end
    end
  end

  describe "require topic/post approval" do
    fab!(:category) { Fabricate(:category_with_definition) }

    it "delegates methods to category settings" do
      expect(category).to delegate_method(:require_reply_approval).to(:category_setting)
      expect(category).to delegate_method(:require_reply_approval=).with_arguments(true).to(
        :category_setting,
      )
      expect(category).to delegate_method(:require_reply_approval?).to(:category_setting)

      expect(category).to delegate_method(:require_topic_approval).to(:category_setting)
      expect(category).to delegate_method(:require_topic_approval=).with_arguments(true).to(
        :category_setting,
      )
      expect(category).to delegate_method(:require_topic_approval?).to(:category_setting)
    end
  end

  describe "auto bump" do
    it "should correctly automatically bump topics" do
      freeze_time
      category = Fabricate(:category_with_definition, created_at: 1.minute.ago)
      category.clear_auto_bump_cache!

      post1 = create_post(category: category, created_at: 15.seconds.ago)
      _post2 = create_post(category: category, created_at: 10.seconds.ago)
      _post3 = create_post(category: category, created_at: 5.seconds.ago)

      # no limits on post creation or category creation please
      RateLimiter.enable

      time = freeze_time 1.month.from_now

      expect(category.auto_bump_topic!).to eq(false)
      expect(Topic.where(bumped_at: time).count).to eq(0)

      category.num_auto_bump_daily = 2
      category.save!

      expect(category.auto_bump_topic!).to eq(true)
      expect(Topic.where(bumped_at: time).count).to eq(1)
      # our extra bump message
      expect(post1.topic.reload.posts_count).to eq(2)

      time = freeze_time 13.hours.from_now

      expect(category.auto_bump_topic!).to eq(true)
      expect(Topic.where(bumped_at: time).count).to eq(1)

      expect(category.auto_bump_topic!).to eq(false)
      expect(Topic.where(bumped_at: time).count).to eq(1)

      time = freeze_time 1.month.from_now

      category.auto_bump_limiter.clear!
      expect(Category.auto_bump_topic!).to eq(true)
      expect(Topic.where(bumped_at: time).count).to eq(1)

      category.num_auto_bump_daily = ""
      category.save!

      expect(Category.auto_bump_topic!).to eq(false)
    end

    it "should not auto-bump the same topic within the cooldown" do
      freeze_time
      category =
        Fabricate(
          :category_with_definition,
          created_at: 1.minute.ago,
          category_setting_attributes: {
            auto_bump_cooldown_days: 1,
            num_auto_bump_daily: 2,
          },
        )
      category.clear_auto_bump_cache!

      create_post(category: category, created_at: 15.seconds.ago)

      # no limits on post creation or category creation please
      RateLimiter.enable

      time = freeze_time 1.month.from_now

      expect(category.auto_bump_topic!).to eq(true)
      expect(Topic.where(bumped_at: time).count).to eq(1)

      time = freeze_time 13.hours.from_now

      expect(category.auto_bump_topic!).to eq(false)
      expect(Topic.where(bumped_at: time).count).to eq(0)

      time = freeze_time 13.hours.from_now

      expect(category.auto_bump_topic!).to eq(true)
      expect(Topic.where(bumped_at: time).count).to eq(1)
    end

    it "should not automatically bump topics with a bump scheduled" do
      freeze_time
      category = Fabricate(:category_with_definition, created_at: 1.second.ago)
      category.clear_auto_bump_cache!

      post1 = create_post(category: category)

      # no limits on post creation or category creation please
      RateLimiter.enable

      time = freeze_time 1.month.from_now

      expect(category.auto_bump_topic!).to eq(false)
      expect(Topic.where(bumped_at: time).count).to eq(0)

      category.num_auto_bump_daily = 2
      category.save!

      topic = Topic.find_by_id(post1.topic_id)

      TopicTimer.create!(
        user_id: Discourse::SYSTEM_USER_ID,
        topic: topic,
        execute_at: 1.hour.from_now,
        status_type: TopicTimer.types[:bump],
      )

      expect(
        Topic.joins(:topic_timers).where(topic_timers: { status_type: 6, deleted_at: nil }).count,
      ).to eq(1)

      expect(category.auto_bump_topic!).to eq(false)
      expect(Topic.where(bumped_at: time).count).to eq(0)
      # does not include a bump message
      expect(post1.topic.reload.posts_count).to eq(1)
    end
  end

  describe "validate permissions compatibility" do
    fab!(:admin)
    fab!(:group)
    fab!(:group2) { Fabricate(:group) }
    fab!(:parent_category) { Fabricate(:category_with_definition, name: "parent") }
    fab!(:subcategory) do
      Fabricate(:category_with_definition, name: "child1", parent_category_id: parent_category.id)
    end

    context "when changing subcategory permissions" do
      it "it is not valid if permissions are less restrictive" do
        subcategory.set_permissions(group => :readonly)
        subcategory.save!

        parent_category.set_permissions(group => :readonly)
        parent_category.save!

        subcategory.set_permissions(group => :full, group2 => :readonly)

        expect(subcategory.valid?).to eq(false)
        expect(subcategory.errors.full_messages).to contain_exactly(
          I18n.t("category.errors.permission_conflict", group_names: group2.name),
        )
      end

      it "is valid if permissions are same or more restrictive" do
        subcategory.set_permissions(group => :full, group2 => :create_post)
        subcategory.save!

        parent_category.set_permissions(group => :full, group2 => :create_post)
        parent_category.save!

        subcategory.set_permissions(group => :create_post, group2 => :full)

        expect(subcategory.valid?).to eq(true)
      end

      it "is valid if everyone has access to parent category" do
        parent_category.set_permissions(everyone: :readonly)
        parent_category.save!

        subcategory.set_permissions(group => :create_post, group2 => :create_post)

        expect(subcategory.valid?).to eq(true)
      end
    end

    context "when changing parent category permissions" do
      fab!(:subcategory2) do
        Fabricate(:category_with_definition, name: "child2", parent_category_id: parent_category.id)
      end

      it "is not valid if subcategory permissions are less restrictive" do
        subcategory.set_permissions(group => :create_post)
        subcategory.save!
        subcategory2.set_permissions(group => :create_post, group2 => :create_post)
        subcategory2.save!

        parent_category.set_permissions(group => :readonly)

        expect(parent_category.valid?).to eq(false)
        expect(parent_category.errors.full_messages).to contain_exactly(
          I18n.t("category.errors.permission_conflict", group_names: group2.name),
        )
      end

      it "is not valid if the subcategory has no category groups, but the parent does" do
        parent_category.set_permissions(group => :readonly)

        expect(parent_category).not_to be_valid
      end

      it "is valid if subcategory permissions are same or more restrictive" do
        subcategory.set_permissions(group => :create_post)
        subcategory.save!
        subcategory2.set_permissions(group => :create_post, group2 => :create_post)
        subcategory2.save!

        parent_category.set_permissions(group => :full, group2 => :create_post)

        expect(parent_category.valid?).to eq(true)
      end

      it "is valid if everyone has access to parent category" do
        subcategory.set_permissions(group => :create_post)
        subcategory.save
        parent_category.set_permissions(everyone: :readonly)

        expect(parent_category.valid?).to eq(true)
      end
    end
  end

  describe "tree metrics" do
    fab!(:category) { Category.create!(user: user, name: "foo") }

    fab!(:subcategory) { Category.create!(user: user, name: "bar", parent_category: category) }

    context "with a self-parent" do
      before_all { DB.exec(<<-SQL, id: category.id) }
          UPDATE categories
          SET parent_category_id = :id
          WHERE id = :id
        SQL

      describe "#depth_of_descendants" do
        it "should produce max_depth" do
          expect(category.depth_of_descendants(3)).to eq(3)
        end
      end

      describe "#height_of_ancestors" do
        it "should produce max_height" do
          expect(category.height_of_ancestors(3)).to eq(3)
        end
      end
    end

    context "with a prospective self-parent" do
      before { category.parent_category_id = category.id }

      describe "#depth_of_descendants" do
        it "should produce max_depth" do
          expect(category.depth_of_descendants(3)).to eq(3)
        end
      end

      describe "#height_of_ancestors" do
        it "should produce max_height" do
          expect(category.height_of_ancestors(3)).to eq(3)
        end
      end
    end

    context "with a prospective loop" do
      before { category.parent_category_id = subcategory.id }

      describe "#depth_of_descendants" do
        it "should produce max_depth" do
          expect(category.depth_of_descendants(3)).to eq(3)
        end
      end

      describe "#height_of_ancestors" do
        it "should produce max_height" do
          expect(category.height_of_ancestors(3)).to eq(3)
        end
      end
    end

    describe "#depth_of_descendants" do
      it "should be 0 when the category has no descendants" do
        expect(subcategory.depth_of_descendants).to eq(0)
      end

      it "should be 1 when the category has a descendant" do
        expect(category.depth_of_descendants).to eq(1)
      end
    end

    describe "#height_of_ancestors" do
      it "should be 0 when the category has no ancestors" do
        expect(category.height_of_ancestors).to eq(0)
      end

      it "should be 1 when the category has an ancestor" do
        expect(subcategory.height_of_ancestors).to eq(1)
      end
    end
  end

  describe "messageBus" do
    it "does not publish notification level when publishing to /categories" do
      category = Fabricate(:category)
      category.name = "Amazing category"
      messages = MessageBus.track_publish("/categories") { category.save! }

      expect(messages.length).to eq(1)
      message = messages.first

      category_hash = message.data[:categories].first

      expect(category_hash[:name]).to eq(category.name)
      expect(category_hash.key?(:notification_level)).to eq(false)
    end
  end

  describe "#ensure_consistency!" do
    it "creates category topic" do
      # corrupt a category topic
      uncategorized = Category.find(SiteSetting.uncategorized_category_id)
      uncategorized.create_category_definition
      uncategorized.topic.posts.first.destroy!

      # make stuff extra broken
      uncategorized.topic.trash!

      category = Fabricate(:category_with_definition)
      category_destroyed = Fabricate(:category_with_definition)
      category_trashed = Fabricate(:category_with_definition)

      category_topic_id = category.topic.id
      category_destroyed.topic.destroy!
      category_trashed.topic.trash!

      Category.ensure_consistency!
      # step one fix corruption
      expect(uncategorized.reload.topic_id).to eq(nil)

      Category.ensure_consistency!
      # step two don't create a category definition for uncategorized
      expect(uncategorized.reload.topic_id).to eq(nil)

      expect(category.reload.topic_id).to eq(category_topic_id)
      expect(category_destroyed.reload.topic).to_not eq(nil)
      expect(category_trashed.reload.topic).to_not eq(nil)
    end
  end

  describe "#find_by_slug_path" do
    it "works for categories with slugs" do
      category = Fabricate(:category, slug: "cat1")

      expect(Category.find_by_slug_path(["cat1"])).to eq(category)
    end

    it "works for categories without slugs" do
      SiteSetting.slug_generation_method = "none"

      category = Fabricate(:category, slug: "cat1")

      expect(Category.find_by_slug_path(["#{category.id}-category"])).to eq(category)
    end

    it "works for subcategories with slugs" do
      category = Fabricate(:category, slug: "cat1")
      subcategory = Fabricate(:category, slug: "cat2", parent_category: category)

      expect(Category.find_by_slug_path(%w[cat1 cat2])).to eq(subcategory)
    end

    it "works for subcategories without slugs" do
      SiteSetting.slug_generation_method = "none"

      category = Fabricate(:category, slug: "cat1")
      subcategory = Fabricate(:category, slug: "cat2", parent_category: category)

      expect(Category.find_by_slug_path(["cat1", "#{subcategory.id}-category"])).to eq(subcategory)
      expect(
        Category.find_by_slug_path(["#{category.id}-category", "#{subcategory.id}-category"]),
      ).to eq(subcategory)
    end
  end

  describe "#cannot_delete_reason" do
    fab!(:admin)
    let(:guardian) { Guardian.new(admin) }
    fab!(:category)

    describe "when category is uncategorized" do
      it "should return the reason" do
        category = Category.find(SiteSetting.uncategorized_category_id)

        expect(category.cannot_delete_reason).to eq(I18n.t("category.cannot_delete.uncategorized"))
      end
    end

    describe "when category has subcategories" do
      it "should return the right reason" do
        category.subcategories << Fabricate(:category)

        expect(category.cannot_delete_reason).to eq(
          I18n.t("category.cannot_delete.has_subcategories"),
        )
      end
    end

    describe "when category has topics" do
      it "should return the right reason" do
        topic =
          Fabricate(
            :topic,
            title: "</a><script>alert(document.cookie);</script><a>",
            category: category,
          )

        category.reload

        expect(category.cannot_delete_reason).to eq(
          I18n.t(
            "category.cannot_delete.topic_exists",
            count: 1,
            topic_link:
              "<a href=\"#{topic.url}\">&lt;/a&gt;&lt;script&gt;alert(document.cookie);&lt;/script&gt;&lt;a&gt;</a>",
          ),
        )
      end
    end
  end

  describe "#deleting the general category" do
    fab!(:category)

    it "should empty out the general_category_id site_setting" do
      SiteSetting.general_category_id = category.id
      category.destroy

      expect(SiteSetting.general_category_id).to_not eq(category.id)
      expect(SiteSetting.general_category_id).to be < 1
    end
  end

  describe ".ids_from_slugs" do
    fab!(:category) { Fabricate(:category, slug: "category") }
    fab!(:category2) { Fabricate(:category, slug: "category2") }
    fab!(:subcategory) { Fabricate(:category, parent_category: category, slug: "subcategory") }
    fab!(:subcategory2) { Fabricate(:category, parent_category: category2, slug: "subcategory") }

    it "returns [] when inputs is []" do
      expect(Category.ids_from_slugs([])).to eq([])
    end

    it 'returns the ids of category when input is ["category"]' do
      expect(Category.ids_from_slugs(%w[category])).to contain_exactly(category.id)
    end

    it 'returns the ids of subcategory when input is ["category:subcategory"]' do
      expect(Category.ids_from_slugs(%w[category:subcategory])).to contain_exactly(subcategory.id)
    end

    it 'returns the ids of subcategory2 when input is ["category2:subcategory"]' do
      expect(Category.ids_from_slugs(%w[category2:subcategory])).to contain_exactly(subcategory2.id)
    end

    it "returns the ids of category and category2 when input is ['category', 'category2']" do
      expect(Category.ids_from_slugs(%w[category category2])).to contain_exactly(
        category.id,
        category2.id,
      )
    end

    it "returns the ids of subcategory and subcategory2 when input is ['category:subcategory', 'category2:subcategory']" do
      expect(
        Category.ids_from_slugs(%w[category:subcategory category2:subcategory]),
      ).to contain_exactly(subcategory.id, subcategory2.id)
    end

    it "returns the ids of subcategory when input is ['category:subcategory', 'invalid:subcategory']" do
      expect(
        Category.ids_from_slugs(%w[category:subcategory invalid:subcategory]),
      ).to contain_exactly(subcategory.id)
    end

    it 'returns the ids of sub-subcategory when input is ["category:subcategory:sub-subcategory"] and maximum category nesting is 3' do
      SiteSetting.max_category_nesting = 3
      sub_subcategory = Fabricate(:category, parent_category: subcategory, slug: "sub-subcategory")

      expect(Category.ids_from_slugs(%w[category:subcategory:sub-subcategory])).to contain_exactly(
        sub_subcategory.id,
      )
    end

    it 'returns nil when input is ["category:invalid-slug:sub-subcategory"] and maximum category nesting is 3' do
      SiteSetting.max_category_nesting = 3
      Fabricate(:category, parent_category: subcategory, slug: "sub-subcategory")

      expect(Category.ids_from_slugs(%w[category:invalid-slug:sub-subcategory])).to eq([])
    end

    it 'returns the ids of subcategory when input is ["category:subcategory:sub-subcategory"] but maximum category nesting is 2' do
      SiteSetting.max_category_nesting = 2

      expect(Category.ids_from_slugs(%w[category:subcategory:sub-subcategory])).to contain_exactly(
        subcategory.id,
      )
    end

    it 'returns the ids of subcategory and subcategory2 when input is ["subcategory"]' do
      expect(Category.ids_from_slugs(%w[subcategory])).to contain_exactly(
        subcategory.id,
        subcategory2.id,
      )
    end
  end

  describe "allowed_tags=" do
    let(:category) { Fabricate(:category) }
    fab!(:tag)
    fab!(:tag2) { Fabricate(:tag) }

    before { SiteSetting.tagging_enabled = true }

    it "can use existing tags for category tags" do
      category.allowed_tags = [tag.name]
      expect_same_tag_names(category.reload.tags, [tag])
    end

    context "with synonyms" do
      fab!(:synonym) { Fabricate(:tag, name: "synonym", target_tag: tag) }

      it "can use existing tags for category tags" do
        category.allowed_tags = [tag.name, synonym.name]
        category.reload
        category.allowed_tags = [tag.name, synonym.name, tag2.name]
        expect_same_tag_names(category.reload.tags, [tag.name, synonym.name, tag2.name])
      end
    end
  end

  describe "#slug_path" do
    before { SiteSetting.max_category_nesting = 3 }

    fab!(:grandparent) { Fabricate(:category, slug: "foo") }
    fab!(:parent) { Fabricate(:category, parent_category: grandparent, slug: "bar") }
    let(:child) { Fabricate(:category, parent_category: parent, slug: "boo") }

    it "returns the slug for categories without parents" do
      expect(grandparent.slug_path).to eq [grandparent.slug]
    end

    it "returns the slug for categories with parent" do
      expect(parent.slug_path).to eq [grandparent.slug, parent.slug]
    end

    it "returns the slug for categories with grand-parent" do
      expect(child.slug_path).to eq [grandparent.slug, parent.slug, child.slug]
    end

    it "avoids infinite loops with circular references" do
      grandparent.parent_category = parent
      grandparent.save!(validate: false)

      expect(grandparent.slug_path).to eq [parent.slug, grandparent.slug]
      expect(parent.slug_path).to eq [grandparent.slug, parent.slug]
    end
  end

  describe "#slug_ref" do
    fab!(:category) { Fabricate(:category, slug: "foo") }

    it "returns the slug for categories without parents" do
      expect(category.slug_ref).to eq("foo")
    end

    context "for category with parent" do
      fab!(:subcategory) { Fabricate(:category, parent_category: category, slug: "bar") }

      it "returns the parent and child slug ref with separator" do
        expect(subcategory.slug_ref).to eq("foo#{Category::SLUG_REF_SEPARATOR}bar")
      end
    end

    context "for category with multiple parents" do
      let(:subcategory_1) { Fabricate(:category, parent_category: category, slug: "bar") }
      let(:subcategory_2) { Fabricate(:category, parent_category: subcategory_1, slug: "boo") }

      before { SiteSetting.max_category_nesting = 3 }

      it "returns the parent and child slug ref with separator" do
        expect(subcategory_2.slug_ref(depth: 2)).to eq(
          "foo#{Category::SLUG_REF_SEPARATOR}bar#{Category::SLUG_REF_SEPARATOR}boo",
        )
      end

      it "allows limiting depth" do
        expect(subcategory_2.slug_ref(depth: 1)).to eq("bar#{Category::SLUG_REF_SEPARATOR}boo")
      end
    end
  end

  describe ".ancestors_of" do
    fab!(:category)
    fab!(:subcategory) { Fabricate(:category, parent_category: category) }

    fab!(:sub_subcategory) do
      SiteSetting.max_category_nesting = 3
      Fabricate(:category, parent_category: subcategory)
    end

    it "finds the parent" do
      expect(Category.ancestors_of([subcategory.id]).to_a).to eq([category])
    end

    it "finds the grandparent" do
      expect(Category.ancestors_of([sub_subcategory.id]).to_a).to contain_exactly(
        category,
        subcategory,
      )
    end

    it "respects the relation it's called on" do
      expect(Category.where.not(id: category.id).ancestors_of([sub_subcategory.id]).to_a).to eq(
        [subcategory],
      )
    end
  end

  describe ".limited_categories_matching" do
    before_all { SiteSetting.max_category_nesting = 3 }

    fab!(:foo) { Fabricate(:category, name: "foo") }
    fab!(:bar) { Fabricate(:category, name: "bar", parent_category: foo) }
    fab!(:baz) { Fabricate(:category, name: "baz", parent_category: bar) }

    it "produces results in depth-first pre-order" do
      SiteSetting.max_category_nesting = 3
      expect(Category.limited_categories_matching(nil, nil, nil, "baz").pluck(:name)).to eq(
        %w[foo bar baz],
      )
    end
  end
end
