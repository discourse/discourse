# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebHookPostSerializer do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:post) { Fabricate(:post) }

  def serialized_for_user(u)
    WebHookPostSerializer.new(post, scope: Guardian.new(u), root: false).as_json
  end

  it 'should only include the required keys' do
    count = serialized_for_user(admin).keys.count
    difference = count - 39

    expect(difference).to eq(0), lambda {
      message = +""

      if difference < 0
        message << "#{difference * -1} key(s) have been removed from this serializer."
      else
        message << "#{difference} key(s) have been added to this serializer."
      end

      message << "\nPlease verify if those key(s) are required as part of the web hook's payload."
    }
  end

  it 'should only include deleted topic title for staffs' do
    topic = post.topic
    PostDestroyer.new(Discourse.system_user, post).destroy
    post.reload

    [nil, post.user, Fabricate(:user)].each do |user|
      expect(serialized_for_user(user)[:topic_title]).to eq(nil)
    end

    [Fabricate(:moderator), admin].each do |user|
      expect(serialized_for_user(user)[:topic_title]).to eq(topic.title)
    end
  end
end
