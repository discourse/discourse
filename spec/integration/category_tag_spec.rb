# encoding: UTF-8

require 'rails_helper'
require_dependency 'post_creator'

describe "category tag restrictions" do

  def sorted_tag_names(tag_records)
    tag_records.map(&:name).sort
  end

  def filter_allowed_tags(opts={})
    DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user), opts)
  end

  let!(:tag1) { Fabricate(:tag) }
  let!(:tag2) { Fabricate(:tag) }
  let!(:tag3) { Fabricate(:tag) }
  let!(:tag4) { Fabricate(:tag) }

  let(:user)  { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.min_trust_to_create_tag = 0
    SiteSetting.min_trust_level_to_tag_topics = 0
  end

  context "tags restricted to one category" do
    let(:category_with_tags) { Fabricate(:category) }
    let(:other_category)     { Fabricate(:category) }

    before do
      category_with_tags.tags = [tag1, tag2]
    end

    it "tags belonging to that category can only be used there" do
      post = create_post(category: category_with_tags, tags: [tag1.name, tag2.name, tag3.name])
      expect(post.topic.tags.map(&:name).sort).to eq([tag1.name, tag2.name].sort)

      post = create_post(category: other_category, tags: [tag1.name, tag2.name, tag3.name])
      expect(post.topic.tags.map(&:name)).to eq([tag3.name])
    end

    it "search can show only permitted tags" do
      expect(filter_allowed_tags.count).to eq(Tag.count)
      expect(filter_allowed_tags({for_input: true, category: category_with_tags}).pluck(:name).sort).to eq([tag1.name, tag2.name].sort)
      expect(filter_allowed_tags({for_input: true}).pluck(:name).sort).to eq([tag3.name, tag4.name].sort)
    end

    it "can't create new tags in a restricted category" do
      post = create_post(category: category_with_tags, tags: [tag1.name, "newtag"])
      expect(post.topic.tags.map(&:name)).to eq([tag1.name])
      post = create_post(category: category_with_tags, tags: [tag1.name, "newtag"], user: admin)
      expect(post.topic.tags.map(&:name)).to eq([tag1.name])
    end

    it "can create new tags in a non-restricted category" do
      post = create_post(category: other_category, tags: [tag3.name, "newtag"])
      expect(post.topic.tags.map(&:name).sort).to eq([tag3.name, "newtag"].sort)
    end

    it "can create tags when changing category settings" do
      expect { other_category.update(allowed_tags: ['newtag']) }.to change { Tag.count }.by(1)
      expect { other_category.update(allowed_tags: [tag1.name, 'tag-stuff', tag2.name, 'another-tag']) }.to change { Tag.count }.by(2)
    end
  end

  context "tag groups restricted to a category" do
    let!(:tag_group1)     { Fabricate(:tag_group) }
    let(:category)        { Fabricate(:category) }
    let(:other_category)  { Fabricate(:category) }

    before do
      tag_group1.tags = [tag1, tag2]
    end

    it "tags in the group are used by category tag restrictions" do
      category.allowed_tag_groups = [tag_group1.name]
      category.reload

      expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: category}))).to eq(sorted_tag_names([tag1, tag2]))
      expect(sorted_tag_names(filter_allowed_tags({for_input: true}))).to eq(sorted_tag_names([tag3, tag4]))

      tag_group1.tags = [tag2, tag3, tag4]
      expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: category}))).to eq(sorted_tag_names([tag2, tag3, tag4]))
      expect(sorted_tag_names(filter_allowed_tags({for_input: true}))).to eq(sorted_tag_names([tag1]))
      expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: other_category}))).to eq(sorted_tag_names([tag1]))
    end

    it "groups and individual tags can be mixed" do
      category.allowed_tag_groups = [tag_group1.name]
      category.allowed_tags = [tag4.name]
      category.reload

      expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: category}))).to eq(sorted_tag_names([tag1, tag2, tag4]))
      expect(sorted_tag_names(filter_allowed_tags({for_input: true}))).to eq(sorted_tag_names([tag3]))
      expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: other_category}))).to eq(sorted_tag_names([tag3]))
    end
  end

  context "tag groups with parent tag" do
    it "filter_allowed_tags returns results based on whether parent tag is present or not" do
      tag_group = Fabricate(:tag_group, parent_tag_id: tag1.id)
      tag_group.tags = [tag3, tag4]
      expect(sorted_tag_names(filter_allowed_tags({for_input: true}))).to eq(sorted_tag_names([tag1, tag2]))
      expect(sorted_tag_names(filter_allowed_tags({for_input: true, selected_tags: [tag1.name]}))).to eq(sorted_tag_names([tag1, tag2, tag3, tag4]))
      expect(sorted_tag_names(filter_allowed_tags({for_input: true, selected_tags: [tag1.name, tag3.name]}))).to eq(sorted_tag_names([tag1, tag2, tag3, tag4]))
    end

    context "and category restrictions" do
      let(:car_category)    { Fabricate(:category) }
      let(:other_category)  { Fabricate(:category) }
      let(:makes)           { Fabricate(:tag_group, name: "Makes") }
      let(:honda_group)     { Fabricate(:tag_group, name: "Honda Models") }
      let(:ford_group)      { Fabricate(:tag_group, name: "Ford Models") }

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
        expect(sorted_tag_names(filter_allowed_tags({for_input: true}))).to eq(sorted_tag_names([tag1, tag2, tag3, tag4]))
        expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: other_category}))).to eq(sorted_tag_names([tag1, tag2, tag3, tag4]))

        # in car category, a make tag must be given first:
        expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: car_category}))).to eq(['ford', 'honda'])

        # model tags depend on which make is chosen:
        expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: car_category, selected_tags: ['honda']}))).to eq(['accord', 'civic', 'ford', 'honda'])
        expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: car_category, selected_tags: ['ford']}))).to eq(['ford', 'honda', 'mustang', 'taurus'])
      end

      it "can apply the tags to a topic" do
        post = create_post(category: car_category, tags: ['ford', 'mustang'])
        expect(post.topic.tags.map(&:name).sort).to eq(['ford', 'mustang'])
      end

      context "limit one tag from each group" do
        before do
          makes.update_attributes(one_per_topic: true)
          honda_group.update_attributes(one_per_topic: true)
          ford_group.update_attributes(one_per_topic: true)
        end

        it "can restrict one tag from each group" do
          expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: car_category}))).to eq(['ford', 'honda'])
          expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: car_category, selected_tags: ['honda']}))).to eq(['accord', 'civic', 'honda'])
          expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: car_category, selected_tags: ['ford']}))).to eq(['ford', 'mustang', 'taurus'])
          expect(sorted_tag_names(filter_allowed_tags({for_input: true, category: car_category, selected_tags: ['ford', 'mustang']}))).to eq(['ford', 'mustang'])
        end

        it "can apply the tags to a topic" do
          post = create_post(category: car_category, tags: ['ford', 'mustang'])
          expect(post.topic.tags.map(&:name).sort).to eq(['ford', 'mustang'])
        end

        it "can remove extra tags from the same group" do
          # A weird case that input field wouldn't allow.
          # Only one tag from car makers is allowed, but we're saying that two have been selected.
          names = filter_allowed_tags({for_input: true, category: car_category, selected_tags: ['honda', 'ford']}).map(&:name)
          expect(names.include?('honda') && names.include?('ford')).to eq(false)
          expect(names.include?('honda') || names.include?('ford')).to eq(true)
        end
      end
    end
  end
end
