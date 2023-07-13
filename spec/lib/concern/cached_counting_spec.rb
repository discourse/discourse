# frozen_string_literal: true

class TestCachedCounting
  def self.clear!
    @data = nil
  end

  def self.data
    @data ||= {}
  end

  def self.write_cache!(key, count, date)
    data[key] = count
  end
end

RSpec.describe CachedCounting do
  it "should be default disabled in test" do
    expect(CachedCounting.enabled?).to eq(false)
  end

  describe "backing implementation" do
    it "can correctly check for flush to db lock" do
      CachedCounting.clear_flush_to_db_lock!

      expect(CachedCounting.allowed_to_flush_to_db?).to eq(true)
      expect(CachedCounting.allowed_to_flush_to_db?).to eq(false)
      t = CachedCounting::DB_FLUSH_COOLDOWN_SECONDS
      # let expiry be between 2 seconds to allow for slow calls and so on
      expect(CachedCounting.flush_to_db_lock_ttl).to be_between(t - 2, t)

      CachedCounting.clear_flush_to_db_lock!
    end

    context "with a test counting class" do
      before do
        CachedCounting.reset
        TestCachedCounting.clear!
      end

      it "can dispatch counts to backing class" do
        CachedCounting.queue("a,a", TestCachedCounting)
        CachedCounting.queue("a,a", TestCachedCounting)
        CachedCounting.queue("b", TestCachedCounting)

        CachedCounting.flush_in_memory
        CachedCounting.flush_to_db

        expect(TestCachedCounting.data).to eq({ "a,a" => 2, "b" => 1 })
      end
    end
  end

  describe "active record" do
    class RailsCacheCounter < ActiveRecord::Base
      include CachedCounting
      self.table_name = "posts"

      def self.cache_data
        @cache_data ||= {}
      end

      def self.clear_cache_data
        @cache_data = nil
      end

      def self.write_cache!(key, val, date)
        cache_data[[key, date]] = val
      end
    end

    before do
      CachedCounting.reset
      CachedCounting.enable
    end

    after { CachedCounting.disable }

    it "can dispatch data via background thread" do
      freeze_time
      d1 = Time.now.utc.to_date

      RailsCacheCounter.perform_increment!("a,a", async: true)
      RailsCacheCounter.perform_increment!("b", async: true)
      20.times { RailsCacheCounter.perform_increment!("a,a", async: true) }

      freeze_time 2.days.from_now
      d2 = Time.now.utc.to_date

      RailsCacheCounter.perform_increment!("a,a", async: true)
      RailsCacheCounter.perform_increment!("d", async: true)

      CachedCounting.flush

      expected = { ["a,a", d1] => 21, ["b", d1] => 1, ["a,a", d2] => 1, ["d", d2] => 1 }

      expect(RailsCacheCounter.cache_data).to eq(expected)
    end
  end
end
