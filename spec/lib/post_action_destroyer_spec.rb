# frozen_string_literal: true

describe PostActionDestroyer do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:post) { Fabricate(:post) }

  context 'like' do
    context 'post action exists' do
      before do
        PostActionCreator.new(user, post, PostActionType.types[:like]).perform
      end

      describe 'perform' do
        it 'destroys the post action' do
          expect {
            PostActionDestroyer.destroy(user, post, :like)
          }.to change { PostAction.count }.by(-1)
        end

        it 'notifies subscribers' do
          expect(post.reload.like_count).to eq(1)

          messages = MessageBus.track_publish do
            PostActionDestroyer.destroy(user, post, :like)
          end

          message = messages.last.data
          expect(message[:type]).to eq(:liked)
          expect(message[:likes_count]).to eq(0)
        end
      end
    end

    context 'post action doesn’t exist' do
      describe 'perform' do
        it 'fails' do
          result = PostActionDestroyer.destroy(user, post, :like)
          expect(result.success).to eq(false)
          expect(result.not_found).to eq(true)
        end
      end
    end
  end

  context 'any other notifiable type' do
    before do
      PostActionCreator.new(user, post, PostActionType.types[:spam]).perform
    end

    describe 'perform' do
      it 'destroys the post action' do
        expect {
          PostActionDestroyer.destroy(user, post, :spam)
        }.to change { PostAction.count }.by(-1)
      end

      it 'notifies subscribers' do
        messages = MessageBus.track_publish do
          PostActionDestroyer.destroy(user, post, :spam)
        end

        expect(messages.last.data[:type]).to eq(:acted)
      end
    end
  end

  context 'not notifyable type' do
    before do
      PostActionCreator.new(user, post, PostActionType.types[:bookmark]).perform
    end

    describe 'perform' do
      it 'destroys the post action' do
        expect {
          PostActionDestroyer.destroy(user, post, :bookmark)
        }.to change { PostAction.count }.by(-1)
      end

      it 'doesn’t notify subscribers' do
        messages = MessageBus.track_publish do
          PostActionDestroyer.destroy(user, post, :bookmark)
        end

        expect(messages).to be_blank
      end
    end
  end
end
