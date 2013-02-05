require 'spec_helper'
require 'discourse_event'
require 'ostruct'

describe DiscourseEvent do

  it "doesn't raise an error if we call an event that doesn't exist" do
    DiscourseEvent.trigger(:missing_event)
  end

  context 'with an event to call' do

    let(:harvey) { OpenStruct.new(name: 'Harvey Dent', job: 'District Attorney') }

    before do
      DiscourseEvent.on(:acid_face) do |user|
        user.name = 'Two Face'
      end
    end

    it "doesn't raise an error" do
      DiscourseEvent.trigger(:acid_face, harvey)      
    end

    it "chnages the name" do
      DiscourseEvent.trigger(:acid_face, harvey)      
      harvey.name.should == 'Two Face'
    end

    context 'multiple events' do
      before do
        DiscourseEvent.on(:acid_face) do |user|
          user.job =  'Supervillian'
        end        
        DiscourseEvent.trigger(:acid_face, harvey)
      end

      it 'triggerred the email event' do
        harvey.job.should == 'Supervillian'
      end

      it 'triggerred the username change' do
        harvey.name.should == 'Two Face'
      end
    end

  end

end
