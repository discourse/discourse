# frozen_string_literal: true

RSpec.describe PostActionDestroyer do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:post) { Fabricate(:post) }

  describe '#perform' do
    context 'with like' do
      context 'when post action exists' do
        before do
          PostActionCreator.new(user, post, PostActionType.types[:like]).perform
        end

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

          message = messages.find { |msg| msg.data[:type] === :unliked }.data
          expect(message).to be_present
          expect(message[:type]).to eq(:unliked)
          expect(message[:likes_count]).to eq(0)
          expect(message[:user_id]).to eq(user.id)
        end

        it 'notifies updated topic stats to subscribers' do
          topic = Fabricate(:topic)
          post = Fabricate(:post, topic: topic)
          PostActionCreator.new(user, post, PostActionType.types[:like]).perform

          expect(post.reload.like_count).to eq(1)

          messages = MessageBus.track_publish("/topic/#{topic.id}") do
            PostActionDestroyer.destroy(user, post, :like)
          end

          stats_message = messages.select { |msg| msg.data[:type] == :stats }.first
          expect(stats_message).to be_present
          expect(stats_message.data[:like_count]).to eq(0)
        end
      end

      context 'when post action doesn’t exist' do
        it 'fails' do
          result = PostActionDestroyer.destroy(user, post, :like)
          expect(result.success).to eq(false)
          expect(result.not_found).to eq(true)
        end
      end
    end

    context 'with any other notifiable type' do
      before do
        PostActionCreator.new(user, post, PostActionType.types[:spam]).perform
      end

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
end
