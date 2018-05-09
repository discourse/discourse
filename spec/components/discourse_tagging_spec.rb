# encoding: UTF-8

require 'rails_helper'
require 'discourse_tagging'

# More tests are found in the category_tag_spec integration specs

describe DiscourseTagging do

  let(:admin) { Fabricate(:admin) }
  let(:user)  { Fabricate(:user) }

  let!(:tag1) { Fabricate(:tag, name: "fun") }
  let!(:tag2) { Fabricate(:tag, name: "fun2") }
  let!(:tag3) { Fabricate(:tag, name: "fun3") }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.min_trust_to_create_tag = 0
    SiteSetting.min_trust_level_to_tag_topics = 0
  end

  describe 'filter_allowed_tags' do
    context 'for input fields' do
      it "doesn't return selected tags if there's a search term" do
        tags = DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user),
          selected_tags: [tag2.name],
          for_input: true,
          term: 'fun'
        ).map(&:name)
        expect(tags).to contain_exactly(tag1.name, tag3.name)
      end

      it "doesn't return selected tags if there's no search term" do
        tags = DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user),
          selected_tags: [tag2.name],
          for_input: true
        ).map(&:name)
        expect(tags).to contain_exactly(tag1.name, tag3.name)
      end

      context 'with tags visible only to staff' do
        let(:hidden_tag) { Fabricate(:tag) }
        let!(:staff_tag_group) { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name]) }

        it 'should return all tags to staff' do
          tags = DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(admin)).to_a
          expect(tags).to contain_exactly(tag1, tag2, tag3, hidden_tag)
          expect(tags.size).to eq(4)
        end

        it 'should not return hidden tag to non-staff' do
          tags = DiscourseTagging.filter_allowed_tags(Tag.all, Guardian.new(user)).to_a
          expect(tags).to contain_exactly(tag1, tag2, tag3)
          expect(tags.size).to eq(3)
        end
      end
    end
  end

  describe 'filter_visible' do
    let(:hidden_tag) { Fabricate(:tag) }
    let!(:staff_tag_group) { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name]) }
    let(:topic) { Fabricate(:topic, tags: [tag1, tag2, tag3, hidden_tag]) }

    it 'returns all tags to staff' do
      tags = DiscourseTagging.filter_visible(topic.tags, Guardian.new(admin))
      expect(tags.size).to eq(4)
      expect(tags).to contain_exactly(tag1, tag2, tag3, hidden_tag)
    end

    it 'does not return hidden tags to non-staff' do
      tags = DiscourseTagging.filter_visible(topic.tags, Guardian.new(user))
      expect(tags.size).to eq(3)
      expect(tags).to contain_exactly(tag1, tag2, tag3)
    end
  end
end
