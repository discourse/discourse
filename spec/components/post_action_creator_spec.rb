require 'rails_helper'
require 'post_action_creator'

describe PostActionCreator do
  let(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post) }
  let(:like_type_id) { PostActionType.types[:like] }

  describe 'perform' do
    it 'creates a post action' do
      expect { PostActionCreator.new(user, post).perform(like_type_id) }.to change { PostAction.count }.by(1)
      expect(PostAction.find_by(user: user, post: post, post_action_type_id: like_type_id)).to be_present
    end

    it 'does not create an invalid post action' do
      expect { PostActionCreator.new(user, nil).perform(like_type_id) }.to raise_error(Discourse::InvalidAccess)
    end
  end

end
