# encoding: UTF-8

require 'rails_helper'
require 'discourse_tagging'

# More tests are found in the category_tag_spec integration specs

describe DiscourseTagging do

  let(:user)  { Fabricate(:user) }

  let!(:tag1) { Fabricate(:tag, name: "tag1") }
  let!(:tag2) { Fabricate(:tag, name: "tag2") }
  let!(:tag3) { Fabricate(:tag, name: "tag3") }

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
          term: 'tag'
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
    end
  end
end
