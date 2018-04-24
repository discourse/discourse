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

    it 'returns staff only tags to everyone' do
      create_staff_tags(['important'])
      staff_tag = Tag.where(name: 'important').first
      topic.tags << staff_tag
      tags = DiscourseTagging.filter_visible(topic.tags, Guardian.new(user))
      expect(tags.size).to eq(4)
      expect(tags).to contain_exactly(tag1, tag2, tag3, staff_tag)
    end
  end

  describe 'tag_topic_by_names' do
    context 'staff-only tags' do
      let(:topic) { Fabricate(:topic) }

      before do
        create_staff_tags(['alpha'])
      end

      it "regular users can't add staff-only tags" do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), ['alpha'])
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(I18n.t("tags.staff_tag_disallowed", tag: 'alpha'))
      end

      it 'staff can add staff-only tags' do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), ['alpha'])
        expect(valid).to eq(true)
        expect(topic.errors[:base]).to be_empty
      end
    end

    context 'respects category minimum_required_tags setting' do
      let(:category) { Fabricate(:category, minimum_required_tags: 2) }
      let(:topic) { Fabricate(:topic, category: category) }

      it 'when tags are not present' do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [])
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(I18n.t("tags.minimum_required_tags", count: category.minimum_required_tags))
      end

      it 'when tags are less than minimum_required_tags' do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag1.name])
        expect(valid).to eq(false)
        expect(topic.errors[:base]&.first).to eq(I18n.t("tags.minimum_required_tags", count: category.minimum_required_tags))
      end

      it 'when tags are equal to minimum_required_tags' do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(user), [tag1.name, tag2.name])
        expect(valid).to eq(true)
        expect(topic.errors[:base]).to be_empty
      end

      it 'lets admin tag a topic regardless of minimum_required_tags' do
        valid = DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), [tag1.name])
        expect(valid).to eq(true)
        expect(topic.errors[:base]).to be_empty
      end
    end

    context 'hidden tags' do
      let(:hidden_tag) { Fabricate(:tag) }
      let!(:staff_tag_group) { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name]) }
      let(:topic) { Fabricate(:topic, user: user) }
      let(:post) { Fabricate(:post, user: user, topic: topic, post_number: 1) }

      it 'user cannot add hidden tag by knowing its name' do
        expect(PostRevisor.new(post).revise!(topic.user, raw: post.raw + " edit", tags: [hidden_tag.name])).to be_falsey
        expect(topic.reload.tags).to be_empty
      end

      it 'admin can add hidden tag' do
        expect(PostRevisor.new(post).revise!(admin, raw: post.raw, tags: [hidden_tag.name])).to be_truthy
        expect(topic.reload.tags).to eq([hidden_tag])
      end

      it 'user does not get an error when editing their topic with a hidden tag' do
        PostRevisor.new(post).revise!(admin, raw: post.raw, tags: [hidden_tag.name])
        expect(PostRevisor.new(post).revise!(topic.user, raw: post.raw + " edit", tags: [])).to be_truthy
        expect(topic.reload.tags).to eq([hidden_tag])
      end
    end
  end
end
