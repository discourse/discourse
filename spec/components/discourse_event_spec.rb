require 'spec_helper'
require_dependency 'discourse_event'

describe DiscourseEvent do

  describe "#events" do
    it "defaults to {}" do
      DiscourseEvent.instance_variable_set(:@events, nil)
      DiscourseEvent.events.should == {}
    end

    describe "key value" do
      it "defaults to an empty set" do
        DiscourseEvent.events["event42"].should == Set.new
      end
    end
  end

  describe ".clear" do
    it "clears out events" do
      DiscourseEvent.events["event42"] << "test event"
      DiscourseEvent.clear
      DiscourseEvent.events.should be_empty
    end
  end

  context 'when calling events' do

    let(:harvey) {
      OpenStruct.new(
        name: 'Harvey Dent',
        job: 'District Attorney'
      )
    }

    before do
      DiscourseEvent.on(:acid_face) do |user|
        user.name = 'Two Face'
      end
    end

    context 'when event does not exist' do

      it "does not raise an error" do
        DiscourseEvent.trigger(:missing_event)
      end

    end

    context 'when single event exists' do

      it "doesn't raise an error" do
        DiscourseEvent.trigger(:acid_face, harvey)
      end

      it "changes the name" do
        DiscourseEvent.trigger(:acid_face, harvey)
        harvey.name.should == 'Two Face'
      end

    end

    context 'when multiple events exist' do

      before do
        DiscourseEvent.on(:acid_face) do |user|
          user.job =  'Supervillian'
        end

        DiscourseEvent.trigger(:acid_face, harvey)
      end

      it 'triggers both events' do
        harvey.job.should == 'Supervillian'
        harvey.name.should == 'Two Face'
      end

    end

  end

end
