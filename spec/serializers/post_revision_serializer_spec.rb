require 'rails_helper'

describe PostRevisionSerializer do
  let(:post) { Fabricate(:post, version: 2) }

  context 'hidden tags' do
    let(:public_tag) { Fabricate(:tag, name: 'public') }
    let(:public_tag2) { Fabricate(:tag, name: 'visible') }
    let(:hidden_tag) { Fabricate(:tag, name: 'hidden') }
    let(:hidden_tag2) { Fabricate(:tag, name: 'secret') }

    let(:staff_tag_group) { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name, hidden_tag2.name]) }

    let(:post_revision) do
      Fabricate(:post_revision,
        post: post,
        modifications: { 'tags' => [['public', 'hidden'], ['visible', 'hidden']] }
      )
    end

    let(:post_revision2) do
      Fabricate(:post_revision,
        post: post,
        modifications: { 'tags' => [['visible', 'hidden', 'secret'], ['visible', 'hidden']] }
      )
    end

    before do
      SiteSetting.tagging_enabled = true
      staff_tag_group
      post.topic.tags = [public_tag2, hidden_tag]
    end

    it 'returns all tag changes to staff' do
      json = PostRevisionSerializer.new(post_revision, scope: Guardian.new(Fabricate(:admin)), root: false).as_json
      expect(json[:tags_changes][:previous]).to include(public_tag.name)
      expect(json[:tags_changes][:previous]).to include(hidden_tag.name)
      expect(json[:tags_changes][:current]).to include(public_tag2.name)
      expect(json[:tags_changes][:current]).to include(hidden_tag.name)
    end

    it 'does not return hidden tags to non-staff' do
      json = PostRevisionSerializer.new(post_revision, scope: Guardian.new(Fabricate(:user)), root: false).as_json
      expect(json[:tags_changes][:previous]).to eq([public_tag.name])
      expect(json[:tags_changes][:current]).to eq([public_tag2.name])
    end

    it 'does not show tag modificiatons if changes are not visible to the user' do
      json = PostRevisionSerializer.new(post_revision2, scope: Guardian.new(Fabricate(:user)), root: false).as_json
      expect(json[:tags_changes]).to_not be_present
    end
  end
end
