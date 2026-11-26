# frozen_string_literal: true

require Rails.root.join("db/migrate/20261123051155_backfill_beacon_browser_pageview_counters.rb")

RSpec.describe BackfillBeaconBrowserPageviewCounters do
  let(:anon_piggyback) { 13 }
  let(:anon_mobile_piggyback) { 14 }
  let(:logged_in_piggyback) { 15 }
  let(:anon_beacon) { 17 }
  let(:anon_mobile_beacon) { 18 }
  let(:logged_in_beacon) { 19 }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    freeze_time
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def insert(date, req_type, count)
    DB.exec(<<~SQL, date:, req_type:, count:)
      INSERT INTO application_requests (date, req_type, count) VALUES (:date, :req_type, :count)
    SQL
  end

  def counts
    DB
      .query("SELECT date, req_type, count FROM application_requests")
      .to_h { |row| [[row.date, row.req_type], row.count] }
  end

  it "copies piggyback counters to days without beacon counts for the cohort" do
    history = Date.current - 10
    insert(history, anon_piggyback, 40)
    insert(history, anon_mobile_piggyback, 15)
    insert(history, logged_in_piggyback, 6)
    insert(history, anon_beacon, 0)

    described_class.new.up

    expect(counts).to include(
      [history, anon_beacon] => 40,
      [history, anon_mobile_beacon] => 15,
      [history, logged_in_beacon] => 6,
    )
  end

  it "keeps beacon counters on days with beacon counts for the cohort" do
    day = Date.current - 2
    insert(day, anon_piggyback, 1000)
    insert(day, anon_mobile_piggyback, 400)
    insert(day, logged_in_piggyback, 7)
    insert(day, anon_beacon, 50)

    described_class.new.up

    expect(counts).to include([day, anon_beacon] => 50, [day, logged_in_beacon] => 7)
    expect(counts).not_to have_key([day, anon_mobile_beacon])
  end
end
