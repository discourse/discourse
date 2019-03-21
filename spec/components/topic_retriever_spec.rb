require 'rails_helper'
require_dependency 'topic_retriever'

describe TopicRetriever do
  let(:embed_url) do
    'http://eviltrout.com/2013/02/10/why-discourse-uses-emberjs.html'
  end
  let(:author_username) { 'eviltrout' }
  let(:topic_retriever) do
    TopicRetriever.new(embed_url, author_username: author_username)
  end

  describe '#retrieve' do
    context 'when host is invalid' do
      before { topic_retriever.stubs(:invalid_url?).returns(true) }

      it 'does not perform_retrieve' do
        topic_retriever.expects(:perform_retrieve).never
        topic_retriever.retrieve
      end
    end

    context 'when topics have been retrieived recently' do
      before { topic_retriever.stubs(:retrieved_recently?).returns(true) }

      it 'does not perform_retrieve' do
        topic_retriever.expects(:perform_retrieve).never
        topic_retriever.retrieve
      end
    end

    context 'when host is not invalid' do
      before { topic_retriever.stubs(:invalid_url?).returns(false) }

      context 'when topics have been retrieived recently' do
        before { topic_retriever.stubs(:retrieved_recently?).returns(true) }

        it 'does not perform_retrieve' do
          topic_retriever.expects(:perform_retrieve).never
          topic_retriever.retrieve
        end
      end

      context 'when topics have not been retrieived recently' do
        before { topic_retriever.stubs(:retrieved_recently?).returns(false) }

        it 'does perform_retrieve' do
          topic_retriever.expects(:perform_retrieve).once
          topic_retriever.retrieve
        end
      end
    end
  end
end
