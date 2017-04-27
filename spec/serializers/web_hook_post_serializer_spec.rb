require 'rails_helper'

RSpec.describe WebHookPostSerializer do
  let(:admin) { Fabricate(:admin) }
  let(:post) { Fabricate(:post) }
  let(:serializer) { WebHookPostSerializer.new(post, scope: Guardian.new(admin), root: false) }

  it 'should only include the required keys' do
    count = serializer.as_json.keys.count
    difference = count - 40

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
