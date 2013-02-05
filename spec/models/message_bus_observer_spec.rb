require 'spec_helper'

describe MessageBusObserver do

  context 'after create topic' do

    after do
      @topic = Fabricate(:topic)
    end

    it 'publishes the topic to the list' do

    end

  end


end
