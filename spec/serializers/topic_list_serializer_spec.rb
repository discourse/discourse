require 'rails_helper'

RSpec.describe TopicListSerializer do
  let(:user) { Fabricate(:user) }

  let(:topic) do
    Fabricate(:topic).tap do |t|
      t.allowed_user_ids = [t.user_id]
    end
  end

  it 'should return the right payload' do
    topic_list = TopicList.new(nil, user, [topic])

    serialized = described_class.new(topic_list,
      scope: Guardian.new(user)
    ).as_json

    expect(serialized[:users].first[:id]).to eq(topic.user_id)
    expect(serialized[:primary_groups]).to eq([])
    expect(serialized[:topic_list][:topics].first[:id]).to eq(topic.id)
  end
end
