# frozen_string_literal: true

RSpec.describe ApplicationRequest do
  before do
    ApplicationRequest.enable
    CachedCounting.reset
    CachedCounting.enable
  end

  after do
    ApplicationRequest.disable
    CachedCounting.disable
  end

  def inc(key)
    ApplicationRequest.increment!(key)
  end

  it "can log app requests" do
    freeze_time
    d1 = Time.now.utc.to_date

    4.times { inc("http_2xx") }

    inc("http_background")

    freeze_time 1.day.from_now
    d2 = Time.now.utc.to_date

    inc("page_view_crawler")
    inc("http_2xx")

    CachedCounting.flush

    expect(ApplicationRequest.find_by(date: d1, req_type: "http_2xx").count).to eq(4)
    expect(ApplicationRequest.find_by(date: d1, req_type: "http_background").count).to eq(1)

    expect(ApplicationRequest.find_by(date: d2, req_type: "page_view_crawler").count).to eq(1)
    expect(ApplicationRequest.find_by(date: d2, req_type: "http_2xx").count).to eq(1)
  end
end
