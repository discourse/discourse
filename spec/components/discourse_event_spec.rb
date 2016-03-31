require 'rails_helper'
require_dependency 'discourse_event'

describe DiscourseEvent do

  describe "#events" do
    it "defaults to {}" do
      DiscourseEvent.instance_variable_set(:@events, nil)
      expect(DiscourseEvent.events).to eq({})
    end

    describe "key value" do
      it "defaults to an empty set" do
        expect(DiscourseEvent.events["event42"]).to eq(Set.new)
      end
    end
  end

  describe ".clear" do
    it "clears out events" do
      DiscourseEvent.events["event42"] << "test event"
      DiscourseEvent.clear
      expect(DiscourseEvent.events).to be_empty
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
        expect(harvey.name).to eq('Two Face')
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
        expect(harvey.job).to eq('Supervillian')
        expect(harvey.name).to eq('Two Face')
      end

    end

  end

end
