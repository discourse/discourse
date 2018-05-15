require 'rails_helper'
require_dependency 'jobs/base'

describe Jobs::RetrieveReport do
  it "correctly included full day in report" do
    freeze_time '2016-02-03 10:00'.to_date

    _topic = Fabricate(:topic)

    args = {
      report_type: :topics,
      start_date: Time.now.beginning_of_day,
      end_date: Time.now.end_of_day,
      facets: [:total]
    }.to_json

    messages = MessageBus.track_publish("/admin/reports/topics") do
      Jobs::RetrieveReport.new.execute(JSON.parse(args))
    end

    data = messages.first.data[:data]
    expect(data).to eq([y: 1, x: Time.now.to_date])
  end
end
