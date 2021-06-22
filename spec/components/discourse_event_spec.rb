# frozen_string_literal: true

require 'rails_helper'

describe DiscourseEvent do

  describe "#events" do
    it "defaults to {}" do
      begin
        original_events = DiscourseEvent.events
        DiscourseEvent.instance_variable_set(:@events, nil)
        expect(DiscourseEvent.events).to eq({})
      ensure
        DiscourseEvent.instance_variable_set(:@events, original_events)
      end
    end

    describe "key value" do
      it "defaults to an empty set" do
        expect(DiscourseEvent.events["event42"]).to eq(Set.new)
      end
    end
  end

  context 'when calling events' do

    let(:harvey) {
      OpenStruct.new(
        name: 'Harvey Dent',
        job: 'District Attorney'
      )
    }

    let(:event_handler) do
      Proc.new { |user| user.name = 'Two Face' }
    end

    before do
      DiscourseEvent.on(:acid_face, &event_handler)
    end

    after do
      DiscourseEvent.off(:acid_face, &event_handler)
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

      let(:event_handler_2) do
        Proc.new { |user| user.job = 'Supervillain' }
      end

      before do
        DiscourseEvent.on(:acid_face, &event_handler_2)
        DiscourseEvent.trigger(:acid_face, harvey)
      end

      after do
        DiscourseEvent.off(:acid_face, &event_handler_2)
      end

      it 'triggers both events' do
        expect(harvey.job).to eq('Supervillain')
        expect(harvey.name).to eq('Two Face')
      end
    end

    context '#all_off' do

      let(:event_handler_2) do
        Proc.new { |user| user.job = 'Supervillain' }
      end

      before do
        DiscourseEvent.on(:acid_face, &event_handler_2)
      end

      it 'removes all handlers with a key' do
        harvey.job = 'gardening'
        DiscourseEvent.all_off(:acid_face)
        DiscourseEvent.trigger(:acid_face, harvey) # Doesn't change anything
        expect(harvey.job).to eq('gardening')
      end

    end
  end
end
