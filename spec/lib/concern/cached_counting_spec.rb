# frozen_string_literal: true

require 'rails_helper'

class TestCachedCounting
  def self.clear!
    @data = nil
  end

  def self.data
    @data ||= {}
  end

  def self.write_cache!(key, count)
    data[key] = count
  end
end

describe CachedCounting do

  it "should be default disabled in test" do
    expect(CachedCounting.enabled?).to eq(false)
  end

  context "backing implementation" do

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
        CachedCounting.clear_queue!
        CachedCounting.clear_flush_to_db_lock!
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

  context "active record" do
    class RailsCacheCounter < ActiveRecord::Base
      include CachedCounting
      self.table_name = "posts"

      def self.cache_data
        @cache_data ||= {}
      end

      def self.clear_cache_data
        @cache_data = nil
      end

      def self.write_cache!(key, val)
        cache_data[key] = val
      end
    end

    before do
      CachedCounting.clear_queue!
      CachedCounting.clear_flush_to_db_lock!
      CachedCounting.enable
    end

    after do
      CachedCounting.disable
    end

    it "can dispatch data via background thread" do
      RailsCacheCounter.perform_increment!("a,a")
      RailsCacheCounter.perform_increment!("b")
      20.times do
        RailsCacheCounter.perform_increment!("a,a")
      end

      CachedCounting.flush

      expect(RailsCacheCounter.cache_data).to eq({ "a,a" => 21, "b" => 1 })
    end
  end
end
