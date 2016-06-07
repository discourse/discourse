# encoding: UTF-8

require 'rails_helper'
require_dependency 'post_creator'

describe "category tag restrictions" do

  def sorted_tag_names(tag_records)
    tag_records.map(&:name).sort
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
      expect(DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user)).count).to eq(Tag.count)
      expect(DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user), {for_input: true, category: category_with_tags}).pluck(:name).sort).to eq([tag1.name, tag2.name].sort)
      expect(DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user), {for_input: true}).pluck(:name).sort).to eq([tag3.name, tag4.name].sort)
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

      expect(sorted_tag_names(DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user), {for_input: true, category: category}))).to eq(sorted_tag_names([tag1, tag2]))
      expect(sorted_tag_names(DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user), {for_input: true}))).to eq(sorted_tag_names([tag3, tag4]))

      tag_group1.tags = [tag2, tag3, tag4]
      expect(sorted_tag_names(DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user), {for_input: true, category: category}))).to eq(sorted_tag_names([tag2, tag3, tag4]))
      expect(sorted_tag_names(DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user), {for_input: true}))).to eq(sorted_tag_names([tag1]))
      expect(sorted_tag_names(DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user), {for_input: true, category: other_category}))).to eq(sorted_tag_names([tag1]))
    end

    it "groups and individual tags can be mixed" do
      category.allowed_tag_groups = [tag_group1.name]
      category.allowed_tags = [tag4.name]
      category.reload

      expect(sorted_tag_names(DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user), {for_input: true, category: category}))).to eq(sorted_tag_names([tag1, tag2, tag4]))
      expect(sorted_tag_names(DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user), {for_input: true}))).to eq(sorted_tag_names([tag3]))
      expect(sorted_tag_names(DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user), {for_input: true, category: other_category}))).to eq(sorted_tag_names([tag3]))
    end
  end
end
