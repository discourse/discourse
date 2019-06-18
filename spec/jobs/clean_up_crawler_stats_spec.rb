# frozen_string_literal: true

require 'rails_helper'

describe Jobs::CleanUpCrawlerStats do
  subject { Jobs::CleanUpCrawlerStats.new.execute({}) }

  it "deletes records older than 30 days old" do
    freeze_time

    today = Fabricate(:web_crawler_request, date: Time.zone.now.to_date)
    yesterday = Fabricate(:web_crawler_request, date: 1.day.ago.to_date)
    too_old = Fabricate(:web_crawler_request, date: 31.days.ago.to_date)

    expect { subject }.to change { WebCrawlerRequest.count }.by(-1)
    expect(WebCrawlerRequest.where(id: too_old.id)).to_not exist
  end

  it "keeps only the top records from the previous day" do
    freeze_time

    WebCrawlerRequest.stubs(:max_records_per_day).returns(3)

    req1 = Fabricate(:web_crawler_request, date: 1.day.ago.to_date, count: 100)
    req4 = Fabricate(:web_crawler_request, date: 1.day.ago.to_date, count: 30)
    req3 = Fabricate(:web_crawler_request, date: 1.day.ago.to_date, count: 40)
    req2 = Fabricate(:web_crawler_request, date: 1.day.ago.to_date, count: 50)
    req5 = Fabricate(:web_crawler_request, date: 1.day.ago.to_date, count: 1)

    expect { subject }.to change { WebCrawlerRequest.count }.by(-2)
    expect(WebCrawlerRequest.all).to contain_exactly(req1, req2, req3)
  end
end
