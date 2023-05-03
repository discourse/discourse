# frozen_string_literal: true

RSpec.describe Jobs::CleanUpCrawlerStats do
  subject { Jobs::CleanUpCrawlerStats.new.execute({}) }

  before do
    # ensure we don't have any records from previous tests
    # some cases may trigger background jobs that will create records
    WebCrawlerRequest.delete_all
  end

  it "deletes records older than 30 days old" do
    freeze_time

    _today = Fabricate(:web_crawler_request, date: Time.zone.now.to_date)
    _yesterday = Fabricate(:web_crawler_request, date: 1.day.ago.to_date)
    too_old = Fabricate(:web_crawler_request, date: 31.days.ago.to_date)

    expect { subject }.to change { WebCrawlerRequest.count }.by(-1)
    expect(WebCrawlerRequest.where(id: too_old.id)).to_not exist
  end

  it "keeps only the top records from the previous day" do
    freeze_time

    WebCrawlerRequest.stubs(:max_records_per_day).returns(3)

    req1 = Fabricate(:web_crawler_request, date: 1.day.ago.to_date, count: 100)
    _req4 = Fabricate(:web_crawler_request, date: 1.day.ago.to_date, count: 30)
    req3 = Fabricate(:web_crawler_request, date: 1.day.ago.to_date, count: 40)
    req2 = Fabricate(:web_crawler_request, date: 1.day.ago.to_date, count: 50)
    _req5 = Fabricate(:web_crawler_request, date: 1.day.ago.to_date, count: 1)

    expect { subject }.to change { WebCrawlerRequest.count }.by(-2)
    expect(WebCrawlerRequest.all).to contain_exactly(req1, req2, req3)
  end
end
