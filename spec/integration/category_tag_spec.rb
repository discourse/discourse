# encoding: UTF-8
# frozen_string_literal: true

require 'rails_helper'

describe "category tag restrictions" do

  def filter_allowed_tags(opts = {})
    DiscourseTagging.filter_allowed_tags(Guardian.new(user), opts)
  end

  fab!(:tag1) { Fabricate(:tag, name: 'tag1') }
  fab!(:tag2) { Fabricate(:tag, name: 'tag2') }
  fab!(:tag3) { Fabricate(:tag, name: 'tag3') }
  fab!(:tag4) { Fabricate(:tag, name: 'tag4') }
  let(:tag_with_colon) { Fabricate(:tag, name: 'with:colon') }

  fab!(:user)  { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.min_trust_to_create_tag = 0
    SiteSetting.min_trust_level_to_tag_topics = 0
  end

  context "tags restricted to one category" do
    fab!(:category_with_tags) { Fabricate(:category) }
    fab!(:other_category)     { Fabricate(:category) }

    before do
      category_with_tags.tags = [tag1, tag2]
    end

    it "tags belonging to that category can only be used there" do
      post = create_post(category: category_with_tags, tags: [tag1.name, tag2.name, tag3.name])
      expect(post.topic.tags).to contain_exactly(tag1, tag2)

      post = create_post(category: other_category, tags: [tag1.name, tag2.name, tag3.name])
      expect(post.topic.tags).to contain_exactly(tag3)
    end

    it "search can show only permitted tags" do
      expect(filter_allowed_tags.count).to eq(Tag.count)
      expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags), [tag1, tag2])
      expect_same_tag_names(filter_allowed_tags(for_input: true), [tag3, tag4])
      expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags, selected_tags: [tag1.name]), [tag2])
      expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags, selected_tags: [tag1.name], term: 'tag'), [tag2])
      expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag3, tag4])
      expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category, selected_tags: [tag3.name]), [tag4])
      expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category, selected_tags: [tag3.name], term: 'tag'), [tag4])
    end

    it "search can handle colons in tag names" do
      tag_with_colon
      expect_same_tag_names(filter_allowed_tags(for_input: true, term: 'with:c'), [tag_with_colon])
    end

    it "can't create new tags in a restricted category" do
      post = create_post(category: category_with_tags, tags: [tag1.name, "newtag"])
      expect_same_tag_names(post.topic.tags, [tag1])
      post = create_post(category: category_with_tags, tags: [tag1.name, "newtag"], user: admin)
      expect_same_tag_names(post.topic.tags, [tag1])
    end

    it "can create new tags in a non-restricted category" do
      post = create_post(category: other_category, tags: [tag3.name, "newtag"])
      expect_same_tag_names(post.topic.tags, [tag3.name, "newtag"])
    end

    it "can create tags when changing category settings" do
      expect { other_category.update(allowed_tags: ['newtag']) }.to change { Tag.count }.by(1)
      expect { other_category.update(allowed_tags: [tag1.name, 'tag-stuff', tag2.name, 'another-tag']) }.to change { Tag.count }.by(2)
    end

    context 'required tags from tag group' do
      fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag3]) }
      before { category_with_tags.update!(required_tag_group: tag_group, min_tags_from_required_group: 1) }

      it "search only returns the allowed tags" do
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags), [tag1])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags, selected_tags: [tag1.name]), [tag2])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags, selected_tags: [tag2.name]), [tag1])
      end
    end

    context 'category allows other tags to be used' do
      before do
        category_with_tags.update!(allow_global_tags: true)
      end

      it "search can show the permitted tags" do
        expect(filter_allowed_tags.count).to eq(Tag.count)
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags), [tag1, tag2, tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true), [tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags, selected_tags: [tag1.name]), [tag2, tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags, selected_tags: [tag1.name], term: 'tag'), [tag2, tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category, selected_tags: [tag3.name]), [tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category, selected_tags: [tag3.name], term: 'tag'), [tag4])
      end

      it "works if no tags are restricted to the category" do
        other_category.update!(allow_global_tags: true)
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category, selected_tags: [tag3.name]), [tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category, selected_tags: [tag3.name], term: 'tag'), [tag4])
      end

      context 'required tags from tag group' do
        fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag3]) }
        before { category_with_tags.update!(required_tag_group: tag_group, min_tags_from_required_group: 1) }

        it "search only returns the allowed tags" do
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags), [tag1, tag3])
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags, selected_tags: [tag1.name]), [tag2, tag3, tag4])
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category_with_tags, selected_tags: [tag2.name]), [tag1, tag3])
        end
      end
    end
  end

  context "tag groups restricted to a category" do
    fab!(:tag_group1)     { Fabricate(:tag_group) }
    fab!(:category)        { Fabricate(:category) }
    fab!(:other_category)  { Fabricate(:category) }

    before do
      tag_group1.tags = [tag1, tag2]
      category.allowed_tag_groups = [tag_group1.name]
      category.reload
    end

    it "tags in the group are used by category tag restrictions" do
      expect_same_tag_names(filter_allowed_tags(for_input: true, category: category), [tag1, tag2])
      expect_same_tag_names(filter_allowed_tags(for_input: true), [tag3, tag4])

      tag_group1.tags = [tag2, tag3, tag4]
      expect_same_tag_names(filter_allowed_tags(for_input: true, category: category), [tag2, tag3, tag4])
      expect_same_tag_names(filter_allowed_tags(for_input: true), [tag1])
      expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag1])
    end

    it "groups and individual tags can be mixed" do
      category.allowed_tags = [tag4.name]
      category.reload

      expect_same_tag_names(filter_allowed_tags(for_input: true, category: category), [tag1, tag2, tag4])
      expect_same_tag_names(filter_allowed_tags(for_input: true), [tag3])
      expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag3])
    end

    it "enforces restrictions when creating a topic" do
      post = create_post(category: category, tags: [tag1.name, "newtag"])
      expect(post.topic.tags.map(&:name)).to eq([tag1.name])
    end

    it "handles colons" do
      tag_with_colon
      expect_same_tag_names(filter_allowed_tags(for_input: true, term: 'with:c'), [tag_with_colon])
    end

    context 'required tags from tag group' do
      fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag3]) }
      before { category.update!(required_tag_group: tag_group, min_tags_from_required_group: 1) }

      it "search only returns the allowed tags" do
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category), [tag1])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category, selected_tags: [tag1.name]), [tag2])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category, selected_tags: [tag2.name]), [tag1])
      end
    end

    context 'category allows other tags to be used' do
      before do
        category.update!(allow_global_tags: true)
      end

      it 'filters tags correctly' do
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category), [tag1, tag2, tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true), [tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag3, tag4])

        tag_group1.tags = [tag2, tag3, tag4]
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category), [tag1, tag2, tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true), [tag1])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag1])
      end

      it "works if no tags are restricted to the category" do
        other_category.update!(allow_global_tags: true)
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag3, tag4])
        tag_group1.tags = [tag2, tag3, tag4]
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag1])
      end

      context 'required tags from tag group' do
        fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag3]) }
        before { category.update!(required_tag_group: tag_group, min_tags_from_required_group: 1) }

        it "search only returns the allowed tags" do
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category), [tag1, tag3])
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category, selected_tags: [tag1.name]), [tag2, tag3, tag4])
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category, selected_tags: [tag2.name]), [tag1, tag3])
        end
      end

      context 'another category has restricted tags using groups' do
        fab!(:category2) { Fabricate(:category) }
        fab!(:tag_group2) { Fabricate(:tag_group) }

        before do
          tag_group2.tags = [tag2, tag3]
          category2.allowed_tag_groups = [tag_group2.name]
          category2.reload
        end

        it 'filters tags correctly' do
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category2), [tag2, tag3])
          expect_same_tag_names(filter_allowed_tags(for_input: true), [tag4])
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag4])
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category), [tag1, tag2, tag4])
        end

        it "doesn't care about tags in a group that isn't used in a category" do
          unused_tag_group = Fabricate(:tag_group)
          unused_tag_group.tags = [tag4]
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category2), [tag2, tag3])
          expect_same_tag_names(filter_allowed_tags(for_input: true), [tag4])
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag4])
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category), [tag1, tag2, tag4])
        end
      end

      context 'another category has restricted tags' do
        fab!(:category2) { Fabricate(:category) }

        it "doesn't filter tags that are also restricted in another category" do
          category2.tags = [tag2, tag3]
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category2), [tag2, tag3])
          expect_same_tag_names(filter_allowed_tags(for_input: true), [tag4])
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag4])
          expect_same_tag_names(filter_allowed_tags(for_input: true, category: category), [tag1, tag2, tag4])
        end
      end
    end
  end

  context "tag groups with parent tag" do
    it "for input field, filter_allowed_tags returns results based on whether parent tag is present or not" do
      tag_group = Fabricate(:tag_group, parent_tag_id: tag1.id)
      tag_group.tags = [tag3, tag4]
      expect_same_tag_names(filter_allowed_tags(for_input: true), [tag1, tag2])
      expect_same_tag_names(filter_allowed_tags(for_input: true, selected_tags: [tag1.name]), [tag2, tag3, tag4])
      expect_same_tag_names(filter_allowed_tags(for_input: true, selected_tags: [tag1.name, tag3.name]), [tag2, tag4])
    end

    it "for tagging a topic, filter_allowed_tags allows tags without parent tag" do
      tag_group = Fabricate(:tag_group, parent_tag_id: tag1.id)
      tag_group.tags = [tag3, tag4]
      expect_same_tag_names(filter_allowed_tags(for_topic: true), [tag1, tag2, tag3, tag4])
      expect_same_tag_names(filter_allowed_tags(for_topic: true, selected_tags: [tag1.name]), [tag1, tag2, tag3, tag4])
      expect_same_tag_names(filter_allowed_tags(for_topic: true, selected_tags: [tag1.name, tag3.name]), [tag1, tag2, tag3, tag4])
    end

    it "filter_allowed_tags returns tags common to more than one tag group with parent tag" do
      common = Fabricate(:tag, name: 'common')
      tag_group = Fabricate(:tag_group, parent_tag_id: tag1.id)
      tag_group.tags = [tag2, common]
      tag_group = Fabricate(:tag_group, parent_tag_id: tag3.id)

      tag_group.tags = [tag4]
      expect_same_tag_names(filter_allowed_tags(for_input: true), [tag1, tag3])
      expect_same_tag_names(filter_allowed_tags(for_input: true, selected_tags: [tag1.name]), [tag2, tag3, common])
      expect_same_tag_names(filter_allowed_tags(for_input: true, selected_tags: [tag3.name]), [tag4, tag1])

      tag_group.tags = [tag4, common]
      expect_same_tag_names(filter_allowed_tags(for_input: true), [tag1, tag3])
      expect_same_tag_names(filter_allowed_tags(for_input: true, selected_tags: [tag1.name]), [tag2, tag3, common])
      expect_same_tag_names(filter_allowed_tags(for_input: true, selected_tags: [tag3.name]), [tag4, tag1, common])

      parent_tag_group = Fabricate(:tag_group, tags: [tag1, tag3])
      expect_same_tag_names(filter_allowed_tags(for_input: true), [tag1, tag3])
      expect_same_tag_names(filter_allowed_tags(for_input: true, selected_tags: [tag1.name]), [tag2, tag3, common])
      expect_same_tag_names(filter_allowed_tags(for_input: true, selected_tags: [tag3.name]), [tag4, tag1, common])

      parent_tag_group.update!(one_per_topic: true)
      expect_same_tag_names(filter_allowed_tags(for_input: true), [tag1, tag3])
      expect_same_tag_names(filter_allowed_tags(for_input: true, selected_tags: [tag1.name]), [tag2, common])
      expect_same_tag_names(filter_allowed_tags(for_input: true, selected_tags: [tag3.name]), [tag4, common])
    end

    context 'required tags from tag group' do
      fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2]) }
      fab!(:category) { Fabricate(:category, required_tag_group: tag_group, min_tags_from_required_group: 1) }

      it "search only returns the allowed tags" do
        tag_group_with_parent = Fabricate(:tag_group, parent_tag_id: tag1.id, tags: [tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category), [tag1, tag2])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category, selected_tags: [tag2.name]), [tag1])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category, selected_tags: [tag1.name]), [tag2, tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: category, selected_tags: [tag1.name, tag2.name]), [tag3, tag4])
      end
    end

    context "and category restrictions" do
      fab!(:car_category)    { Fabricate(:category) }
      fab!(:other_category)  { Fabricate(:category) }
      fab!(:makes)           { Fabricate(:tag_group, name: "Makes") }
      fab!(:honda_group)     { Fabricate(:tag_group, name: "Honda Models") }
      fab!(:ford_group)      { Fabricate(:tag_group, name: "Ford Models") }

      before do
        @tags = {}
        ['honda', 'ford', 'civic', 'accord', 'mustang', 'taurus'].each do |name|
          @tags[name] = Fabricate(:tag, name: name)
        end

        makes.tags = [@tags['honda'], @tags['ford']]

        honda_group.parent_tag_id = @tags['honda'].id
        honda_group.save
        honda_group.tags = [@tags['civic'], @tags['accord']]

        ford_group.parent_tag_id = @tags['ford'].id
        ford_group.save
        ford_group.tags = [@tags['mustang'], @tags['taurus']]

        car_category.allowed_tag_groups = [makes.name, honda_group.name, ford_group.name]
      end

      it "handles all those rules" do
        # car tags can't be used outside of car category:
        expect_same_tag_names(filter_allowed_tags(for_input: true), [tag1, tag2, tag3, tag4])
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: other_category), [tag1, tag2, tag3, tag4])

        # in car category, a make tag must be given first:
        expect(sorted_tag_names(filter_allowed_tags(for_input: true, category: car_category))).to eq(['ford', 'honda'])

        # model tags depend on which make is chosen:
        expect(sorted_tag_names(filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['honda']))).to eq(['accord', 'civic', 'ford'])
        expect(sorted_tag_names(filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['ford']))).to eq(['honda', 'mustang', 'taurus'])

        makes.update!(one_per_topic: true)
        expect(sorted_tag_names(filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['honda']))).to eq(['accord', 'civic'])
        expect(sorted_tag_names(filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['ford']))).to eq(['mustang', 'taurus'])

        honda_group.update!(one_per_topic: true)
        ford_group.update!(one_per_topic: true)
        expect(sorted_tag_names(filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['honda']))).to eq(['accord', 'civic'])
        expect(sorted_tag_names(filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['ford']))).to eq(['mustang', 'taurus'])

        car_category.update!(allow_global_tags: true)
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: car_category),
          ['ford', 'honda', tag1, tag2, tag3, tag4]
        )
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['ford']),
          ['mustang', 'taurus', tag1, tag2, tag3, tag4]
        )
        expect_same_tag_names(filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['ford', 'mustang']),
          [tag1, tag2, tag3, tag4]
        )
      end

      it "can apply the tags to a topic" do
        post = create_post(category: car_category, tags: ['ford', 'mustang'])
        expect(post.topic.tags.map(&:name).sort).to eq(['ford', 'mustang'])
      end

      context "limit one tag from each group" do
        before do
          makes.update(one_per_topic: true)
          honda_group.update(one_per_topic: true)
          ford_group.update(one_per_topic: true)
        end

        it "can restrict one tag from each group" do
          expect(sorted_tag_names(filter_allowed_tags(for_input: true, category: car_category))).to eq(['ford', 'honda'])
          expect(sorted_tag_names(filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['honda']))).to eq(['accord', 'civic'])
          expect(sorted_tag_names(filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['ford']))).to eq(['mustang', 'taurus'])
          expect(sorted_tag_names(filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['ford', 'mustang']))).to eq([])
        end

        it "can apply the tags to a topic" do
          post = create_post(category: car_category, tags: ['ford', 'mustang'])
          expect(post.topic.tags.map(&:name).sort).to eq(['ford', 'mustang'])
        end

        it "can remove extra tags from the same group" do
          # A weird case that input field wouldn't allow.
          # Only one tag from car makers is allowed, but we're saying that two have been selected.
          names = filter_allowed_tags(for_input: true, category: car_category, selected_tags: ['honda', 'ford']).map(&:name)
          expect(names.include?('honda') || names.include?('ford')).to eq(false)
          expect(names).to include('civic')
          expect(names).to include('mustang')
        end
      end
    end
  end
end

describe "tag topic counts per category" do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:category) { Fabricate(:category) }
  fab!(:category2) { Fabricate(:category) }
  fab!(:tag1) { Fabricate(:tag) }
  fab!(:tag2) { Fabricate(:tag) }
  fab!(:tag3) { Fabricate(:tag) }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.min_trust_to_create_tag = 0
    SiteSetting.min_trust_level_to_tag_topics = 0
  end

  it "counts when a topic is created with tags" do
    expect {
      Fabricate(:topic, category: category, tags: [tag1, tag2])
    }.to change { CategoryTagStat.count }.by(2)
    expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(1)
    expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(1)
  end

  it "counts when tag is added to an existing topic" do
    topic = Fabricate(:topic, category: category)
    post = Fabricate(:post, user: topic.user, topic: topic)
    expect(CategoryTagStat.where(category: category).count).to eq(0)
    expect {
      PostRevisor.new(post).revise!(topic.user, raw: post.raw, tags: [tag1.name, tag2.name])
    }.to change { CategoryTagStat.count }.by(2)
    expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(1)
    expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(1)
  end

  context "topic with 2 tags" do
    fab!(:topic) { Fabricate(:topic, category: category, tags: [tag1, tag2]) }
    fab!(:post)  { Fabricate(:post, user: topic.user, topic: topic) }

    it "has correct counts after tag is removed from a topic" do
      post
      topic2 = Fabricate(:topic, category: category, tags: [tag2])
      expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(2)
      PostRevisor.new(post).revise!(topic.user, raw: post.raw, tags: [])
      expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(1)
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(0)
    end

    it "has correct counts after a topic's category changes" do
      PostRevisor.new(post).revise!(topic.user, category_id: category2.id, raw: post.raw, tags: [tag1.name, tag2.name])
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category2, tag: tag1).sum(:topic_count)).to eq(1)
      expect(CategoryTagStat.where(category: category2, tag: tag2).sum(:topic_count)).to eq(1)
    end

    it "has correct counts after topic's category AND tags changed" do
      PostRevisor.new(post).revise!(topic.user, raw: post.raw, tags: [tag2.name, tag3.name], category_id: category2.id)
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category, tag: tag3).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category2, tag: tag1).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category2, tag: tag2).sum(:topic_count)).to eq(1)
      expect(CategoryTagStat.where(category: category2, tag: tag3).sum(:topic_count)).to eq(1)
    end
  end

  context "topic with one tag" do
    fab!(:topic) { Fabricate(:topic, tags: [tag1], category: category) }
    fab!(:post) { Fabricate(:post, user: topic.user, topic: topic) }

    it "counts after topic becomes uncategorized" do
      PostRevisor.new(post).revise!(topic.user, raw: post.raw, tags: [tag1.name], category_id: SiteSetting.uncategorized_category_id)
      expect(CategoryTagStat.where(category: Category.find(SiteSetting.uncategorized_category_id), tag: tag1).sum(:topic_count)).to eq(1)
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(0)
    end

    it "updates counts after topic is deleted" do
      PostDestroyer.new(admin, post).destroy
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(0)
    end

    it "updates counts after topic is recovered" do
      PostDestroyer.new(admin, post).destroy
      PostDestroyer.new(admin, post).recover
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(1)
    end
  end
end
