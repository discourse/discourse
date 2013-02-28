require 'spec_helper'

describe Report do


  describe 'visits report' do

    let(:report) { Report.find('visits') }

    context "no visits" do
      it "returns an empty report" do
        report.data.should be_blank
      end
    end

    context "with visits" do
      let(:user) { Fabricate(:user) }

      before do
        user.user_visits.create(visited_at: 1.day.ago)
        user.user_visits.create(visited_at: 2.days.ago)
      end

      it "returns a report with data" do
        report.data.should be_present
      end

    end


  end


end
