require 'rails_helper'

RSpec.describe WebHookTopicViewSerializer do
  let(:admin) { Fabricate(:admin) }
  let(:topic) { Fabricate(:topic) }

  let(:serializer) do
    WebHookTopicViewSerializer.new(TopicView.new(topic),
      scope: Guardian.new(admin),
      root: false
    )
  end

  it 'should only include the required keys' do
    count = serializer.as_json.keys.count
    difference = count - 30

    expect(difference).to eq(0), lambda {
      message = ""

      if difference < 0
        message << "#{difference * -1} key(s) have been removed from this serializer."
      else
        message << "#{difference} key(s) have been added to this serializer."
      end

      message << "\nPlease verify if those key(s) are required as part of the web hook's payload."
    }
  end
end
