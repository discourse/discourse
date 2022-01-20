# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'AutoResponder' do
  before do
    automation.upsert_field!('word_answer_list', 'key-value', { value: [{ key: 'foo', value: 'this is foo' }, { key: 'bar', value: 'this is bar' }].to_json })
  end

  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scriptable::AUTO_RESPONDER
    )
  end
  fab!(:topic) { Fabricate(:topic) }

  context 'post contains a keyword' do
    it 'creates an answer' do
      post = create_post(topic: topic, raw: 'this is a post with foo')
      automation.trigger!('post' => post)

      expect(topic.reload.posts.last.raw).to eq('this is foo')
    end

    context 'post has direct replies from answering user' do
      fab!(:answering_user) { Fabricate(:user) }

      before do
        automation.upsert_field!('answering_user', 'user', { value: answering_user.username }, target: 'script')
      end

      it 'doesn’t create another answer' do
        post_1 = create_post(topic: topic, raw: 'this is a post with foo')
        create_post(user: answering_user, reply_to_post_number: post_1.post_number, topic: topic)

        expect {
          automation.trigger!('post' => post_1)
        }.to change {
          Post.count
        }.by(0)
      end
    end

    context 'user is replying to own post' do
      fab!(:answering_user) { Fabricate(:user) }

      before do
        automation.upsert_field!('answering_user', 'user', { value: answering_user.username }, target: 'script')
      end

      it 'doesn’t create an answer' do
        post_1 = create_post(topic: topic)
        post_2 = create_post(user: answering_user, topic: topic, reply_to_post_number: post_1.post_number, raw: 'this is a post with foo')

        expect {
          automation.trigger!('post' => post_2)
        }.to change {
          Post.count
        }.by(0)
      end
    end
  end

  context 'post contains two keywords' do
    it 'creates an answer with both answers' do
      post = create_post(topic: topic, raw: 'this is a post with foo and bar')
      automation.trigger!('post' => post)

      expect(topic.reload.posts.last.raw).to eq("this is foo\n\nthis is bar")
    end
  end

  context 'post doesn’t contain a keyword' do
    it 'doesn’t create an answer' do
      post = create_post(topic: topic, raw: 'this is a post bfoo with no keyword fooa')

      expect {
        automation.trigger!('post' => post)
      }.to change {
        Post.count
      }.by(0)
    end
  end
end
