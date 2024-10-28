# frozen_string_literal: true

RSpec.describe Tag do
  def make_some_tags(count: 3, tag_a_topic: false)
    @tags = []
    if tag_a_topic
      count.times { |i| @tags << Fabricate(:tag, topics: [Fabricate(:topic)]) }
    else
      count.times { |i| @tags << Fabricate(:tag) }
    end
  end

  let(:tag) { Fabricate(:tag) }
  let(:tag2) { Fabricate(:tag) }
  let(:topic) { Fabricate(:topic, tags: [tag]) }
  fab!(:user)

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  describe "Associations" do
    it "should delete associated sidebar_section_links when tag is destroyed" do
      tag_sidebar_section_link = Fabricate(:tag_sidebar_section_link)
      tag_sidebar_section_link_2 =
        Fabricate(:tag_sidebar_section_link, linkable: tag_sidebar_section_link.linkable)
      category_sidebar_section_link = Fabricate(:category_sidebar_section_link)

      expect { tag_sidebar_section_link.linkable.destroy! }.to change {
        SidebarSectionLink.count
      }.from(13).to(10)
      expect(SidebarSectionLink.last).to eq(category_sidebar_section_link)
    end
  end

  describe "new" do
    subject(:tag) { Fabricate.build(:tag) }

    it "triggers a extensibility event" do
      event = DiscourseEvent.track_events { tag.save! }.last

      expect(event[:event_name]).to eq(:tag_created)
      expect(event[:params].first).to eq(tag)
    end

    it "prevents case-insensitive duplicates" do
      Fabricate.build(:tag, name: "hello").save!
      expect { Fabricate.build(:tag, name: "hElLo").save! }.to raise_error(
        ActiveRecord::RecordInvalid,
      )
    end

    it 'does not allow creation of tag with name in "RESERVED_TAGS"' do
      expect { Fabricate.build(:tag, name: "None").save! }.to raise_error(
        ActiveRecord::RecordInvalid,
      )
    end
  end

  describe "destroy" do
    subject(:tag) { Fabricate(:tag) }

    it "triggers a extensibility event" do
      event = DiscourseEvent.track_events { tag.destroy! }.last

      expect(event[:event_name]).to eq(:tag_destroyed)
      expect(event[:params].first).to eq(tag)
    end

    it "removes it from its tag group" do
      tag_group = Fabricate(:tag_group, tags: [tag])
      expect { tag.destroy }.to change { TagGroupMembership.count }.by(-1)
      expect(tag_group.reload.tags).to be_empty
    end
  end

  it "can delete tags on deleted topics" do
    topic.trash!
    expect { tag.destroy }.to change { Tag.count }.by(-1)
  end

  describe "#top_tags" do
    it "returns nothing if nothing has been tagged" do
      make_some_tags(tag_a_topic: false)
      expect(Tag.top_tags.sort).to be_empty
    end

    it "can return all tags" do
      make_some_tags(tag_a_topic: true)
      expect(Tag.top_tags.sort).to eq(@tags.map(&:name).sort)
    end

    context "with categories" do
      before do
        make_some_tags(count: 4) # one tag that isn't used
        @category1 = Fabricate(:category)
        @private_category = Fabricate(:category)
        @private_category.set_permissions(admins: :full)
        @private_category.save!
        @topics = []
        @topics << Fabricate(:topic, category: @category1, tags: [@tags[0]])
        @topics << Fabricate(:topic, tags: [@tags[1]])
        @topics << Fabricate(:topic, category: @private_category, tags: [@tags[2]])
      end

      it "works correctly" do
        expect(Tag.top_tags(category: @category1).sort).to eq([@tags[0].name].sort)
        expect(Tag.top_tags(guardian: Guardian.new(Fabricate(:admin))).sort).to eq(
          [@tags[0].name, @tags[1].name, @tags[2].name].sort,
        )
        expect(
          Tag.top_tags(category: @private_category, guardian: Guardian.new(Fabricate(:admin))).sort,
        ).to eq([@tags[2].name].sort)

        expect(Tag.top_tags.sort).to eq([@tags[0].name, @tags[1].name].sort)
        expect(Tag.top_tags(category: @private_category)).to be_empty

        sub_category = Fabricate(:category, parent_category_id: @category1.id)
        Fabricate(:topic, category: sub_category, tags: [@tags[1]])
        expect(Tag.top_tags(category: @category1).sort).to eq([@tags[0].name, @tags[1].name].sort)
      end
    end

    context "with category-specific tags" do
      before do
        make_some_tags(count: 3)
        @category1 = Fabricate(:category, tags: [@tags[0]]) # only one tag allowed in this category
        @category2 = Fabricate(:category)
        @topics = []
        @topics << Fabricate(:topic, category: @category1, tags: [@tags[0]])
        @topics << Fabricate(:topic, category: @category2, tags: [@tags[1], @tags[2]])
        @topics << Fabricate(:topic, tags: [@tags[2]]) # uncategorized
      end

      it "for category with restricted tags, lists those tags" do
        expect(Tag.top_tags(category: @category1)).to eq([@tags[0].name])
      end

      it "for category without tags, lists allowed tags" do
        expect(Tag.top_tags(category: @category2).sort).to eq([@tags[1].name, @tags[2].name].sort)
      end

      it "for no category arg, lists all tags" do
        expect(Tag.top_tags.sort).to eq([@tags[0].name, @tags[1].name, @tags[2].name].sort)
      end
    end

    context "with hidden tags" do
      let(:hidden_tag) { Fabricate(:tag, name: "hidden") }
      let!(:staff_tag_group) do
        Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
      end
      let!(:topic2) { Fabricate(:topic, tags: [tag, hidden_tag]) }

      it "returns all tags to staff" do
        expect(Tag.top_tags(guardian: Guardian.new(Fabricate(:admin)))).to include(hidden_tag.name)
      end

      it "doesn't return hidden tags to anon" do
        expect(Tag.top_tags).to_not include(hidden_tag.name)
      end

      it "doesn't return hidden tags to non-staff" do
        expect(Tag.top_tags(guardian: Guardian.new(Fabricate(:user)))).to_not include(
          hidden_tag.name,
        )
      end
    end
  end

  describe "#pm_tags" do
    let(:regular_user) { Fabricate(:trust_level_4) }
    let(:admin) { Fabricate(:admin) }
    let(:personal_message) do
      Fabricate(
        :private_message_topic,
        user: regular_user,
        topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: regular_user),
          Fabricate.build(:topic_allowed_user, user: admin),
        ],
      )
    end

    before { 2.times { |i| Fabricate(:tag, topics: [personal_message], name: "tag-#{i}") } }

    it "returns nothing if user is not a staff" do
      expect(Tag.pm_tags(guardian: Guardian.new(regular_user))).to be_empty
    end

    it "returns nothing if pm_tags_allowed_for_groups setting is empty" do
      SiteSetting.pm_tags_allowed_for_groups = ""
      expect(Tag.pm_tags(guardian: Guardian.new(admin)).sort).to be_empty
    end

    it "returns all pm tags if user is a staff and pm tagging is enabled" do
      SiteSetting.pm_tags_allowed_for_groups = "1|2|3"
      tags = Tag.pm_tags(guardian: Guardian.new(admin), allowed_user: regular_user)
      expect(tags.length).to eq(2)
      expect(tags.map { |t| t[:id] }).to contain_exactly("tag-0", "tag-1")
    end
  end

  describe ".ensure_consistency!" do
    it "should exclude private message topics" do
      topic
      Fabricate(:private_message_topic, tags: [tag])
      Tag.ensure_consistency!
      tag.reload
      expect(tag.staff_topic_count).to eq(1)
      expect(tag.public_topic_count).to eq(1)
    end

    it "should update Tag#topic_count and Tag#public_topic_count correctly" do
      tag = Fabricate(:tag, name: "tag1")
      tag2 = Fabricate(:tag, name: "tag2")
      tag3 = Fabricate(:tag, name: "tag3")
      group = Fabricate(:group)
      category = Fabricate(:category)
      private_category = Fabricate(:private_category, group: group)
      private_category2 = Fabricate(:private_category, group: group)

      _topic_with_tag = Fabricate(:topic, category: category, tags: [tag])

      _topic_with_tag_in_private_category =
        Fabricate(:topic, category: private_category, tags: [tag])

      _topic_with_tag2_in_private_category2 =
        Fabricate(:topic, category: private_category2, tags: [tag2])

      tag.update!(staff_topic_count: 123, public_topic_count: 456)
      tag2.update!(staff_topic_count: 123, public_topic_count: 456)
      tag3.update!(staff_topic_count: 123, public_topic_count: 456)

      Tag.ensure_consistency!

      tag.reload
      tag2.reload
      tag3.reload

      expect(tag.staff_topic_count).to eq(2)
      expect(tag.public_topic_count).to eq(1)
      expect(tag2.staff_topic_count).to eq(1)
      expect(tag2.public_topic_count).to eq(0)
      expect(tag3.staff_topic_count).to eq(0)
      expect(tag3.public_topic_count).to eq(0)
    end
  end

  describe "unused tags scope" do
    let!(:tags) do
      [
        Fabricate(
          :tag,
          name: "used_publically",
          staff_topic_count: 2,
          public_topic_count: 2,
          pm_topic_count: 0,
        ),
        Fabricate(
          :tag,
          name: "used_privately",
          staff_topic_count: 0,
          public_topic_count: 0,
          pm_topic_count: 3,
        ),
        Fabricate(
          :tag,
          name: "used_everywhere",
          staff_topic_count: 0,
          public_topic_count: 0,
          pm_topic_count: 3,
        ),
        Fabricate(
          :tag,
          name: "unused1",
          staff_topic_count: 0,
          public_topic_count: 0,
          pm_topic_count: 0,
        ),
        Fabricate(
          :tag,
          name: "unused2",
          staff_topic_count: 0,
          public_topic_count: 0,
          pm_topic_count: 0,
        ),
      ]
    end

    let(:tag_in_group) do
      Fabricate(
        :tag,
        name: "unused_in_group",
        public_topic_count: 0,
        staff_topic_count: 0,
        pm_topic_count: 0,
      )
    end
    let!(:tag_group) { Fabricate(:tag_group, tag_names: [tag_in_group.name]) }
    let!(:synonym_tag) { Fabricate(:tag, target_tag: tags.first) }

    it "returns the correct tags" do
      expect(Tag.unused.pluck(:name)).to contain_exactly("unused1", "unused2")
    end
  end

  describe "full_url" do
    let(:tag) { Fabricate(:tag, name: "🚀") }

    it "percent encodes emojis" do
      expect(tag.full_url).to eq("http://test.localhost/tag/%F0%9F%9A%80")
    end
  end

  describe "synonyms" do
    let(:synonym) { Fabricate(:tag, target_tag: tag) }

    it "can be a synonym for another tag" do
      expect(synonym).to be_synonym
      expect(synonym.target_tag).to eq(tag)
    end

    it "cannot have a synonym of a synonym" do
      synonym2 = Fabricate.build(:tag, target_tag: synonym)
      expect(synonym2).to_not be_valid
      expect(synonym2.errors[:target_tag_id]).to be_present
    end

    it "a tag with synonyms cannot become a synonym" do
      synonym
      tag.target_tag = Fabricate(:tag)
      expect(tag).to_not be_valid
      expect(tag.errors[:target_tag_id]).to be_present
    end

    it "can be added to a tag group" do
      tag_group = Fabricate(:tag_group, tags: [tag])
      synonym
      expect(tag_group.reload.tags).to include(synonym)
    end

    it "can be added to a category" do
      category = Fabricate(:category, tags: [tag])
      synonym
      expect(category.reload.tags).to include(synonym)
    end

    it "destroying a tag destroys its synonyms" do
      synonym
      expect { tag.destroy }.to change { Tag.count }.by(-2)
      expect(Tag.find_by_id(synonym.id)).to be_nil
    end

    it "can add a tag from the same tag group as a synonym" do
      tag_group = Fabricate(:tag_group, tags: [tag, tag2])
      tag2.update!(target_tag: tag)
      expect(tag_group.reload.tags).to include(tag2)
    end

    it "can add a tag restricted to the same category as a synonym" do
      category = Fabricate(:category, tags: [tag, tag2])
      tag2.update!(target_tag: tag)
      expect(category.reload.tags).to include(tag2)
    end
  end

  describe ".topic_count_column" do
    fab!(:admin)

    it "returns 'staff_topic_count' when user is staff" do
      expect(Tag.topic_count_column(Guardian.new(admin))).to eq("staff_topic_count")
    end

    it "returns 'public_topic_count' when user is not staff" do
      expect(Tag.topic_count_column(Guardian.new(user))).to eq("public_topic_count")
    end

    it "returns 'staff_topic_count' when user is not staff but `include_secure_categories_in_tag_counts` site setting is enabled" do
      SiteSetting.include_secure_categories_in_tag_counts = true

      expect(Tag.topic_count_column(Guardian.new(user))).to eq("staff_topic_count")
    end
  end

  describe "description" do
    it "uses the HTMLSanitizer to remove unsafe tags and attributes" do
      tag.description =
        "<div>hi</div><script>a=0;</script> <a onclick='const a=0;' href=\"https://www.discourse.org\">discourse</a>"
      tag.save!
      expect(tag.description.strip).to eq(
        "<div>hi</div>a=0; <a href=\"https://www.discourse.org\">discourse</a>",
      )
    end
  end
end
