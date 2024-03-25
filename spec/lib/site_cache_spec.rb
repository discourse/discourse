# frozen_string_literal: true

class MethodLogger
  Log = Struct.new(:method_name, :args, :blk, :result)
  attr_reader :operations

  def initialize(obj)
    @obj = obj
    @operations = []
  end

  def method_missing(method_name, *args, &blk)
    result = @obj.public_send(method_name, *args, &blk)
    @operations << Log.new(method_name, args, blk, result)
    result
  end
end

# This is for exhaustive testing
#
# It allows you to assert that something is true after a number of operations
# no matter what those operations are.
class CachePathGenerator
  def self.complete(global_limit:, site_limit:, &blk)
    Concurrency::Logic::Complete.run do |path|
      blk.call(CachePathGenerator.new(global_limit, site_limit, path))
    end
  end

  attr_reader :path, :cache, :keys

  def initialize(global_limit, site_limit, path)
    @path = path
    @cache =
      MethodLogger.new(SiteCache.new(max_global_size: global_limit, max_size_per_site: site_limit))
    @keys = Hash.new { |h, k| h[k] = [] }
  end

  def generate_lookup_for_site(site_id)
    operation = path.choose(:lookup_existing, :delete_existing)

    public_send(operation, site_id)
    @cache.operations.last
  end

  def generate_lookup
    operation = path.choose(:lookup_existing, :delete_existing)

    public_send(operation)
    @cache.operations.last
  end

  def generate_operation
    operation =
      path.choose(
        :insert_new,
        :insert_existing_site_id,
        :insert_existing_key,
        :lookup_existing,
        :getset_existing,
        :delete_existing,
        :clear,
        :clear_existing_site,
      )

    public_send(operation)
    @cache.operations.last
  end

  def generate_operations(upto:)
    CacheOperations.new(path.choose(*(1..upto)).times.map { generate_operation })
  end

  def insert_new
    site_id = Object.new
    key = Object.new
    keys[site_id] << key
    value = Object.new

    if path.choose(true, false)
      cache.set(site_id, key, value)
    else
      cache.getset(site_id, key) { value }
    end
    [site_id, key, value]
  end

  def insert_existing_site_id
    site_id = path.choose(*keys.keys)
    key = Object.new
    keys[site_id] << key
    value = Object.new

    if path.choose(true, false)
      cache.set(site_id, key, value)
    else
      cache.getset(site_id, key) { value }
    end
  end

  def insert_existing_key
    site_id = path.choose(*keys.keys)
    key = path.choose(*keys[site_id])
    value = Object.new
    cache.set(site_id, key, value)
  end

  def lookup_existing(site_id = nil)
    site_id ||= path.choose(*keys.keys)
    key = path.choose(*keys[site_id])
    cache.lookup(site_id, key)
  end

  def getset_existing
    site_id = path.choose(*keys.keys)
    key = path.choose(*keys[site_id])
    value = Object.new
    cache.getset(site_id, key) { value }
  end

  def delete_existing(site_id = nil)
    site_id ||= path.choose(*keys.keys)
    key = path.choose(*keys[site_id])
    cache.delete(site_id, key)
  end

  def clear
    cache.clear
  end

  def clear_site(site_id)
    cache.clear_site(site_id)
  end

  def clear_existing_site
    site_id = path.choose(*keys.keys)
    cache.clear_site(site_id)
  end
end

class CacheOperations
  def initialize(operations)
    @operations = operations
  end

  def values_inserted_at(site_id, key)
    @operations.filter_map do |op|
      case op.method_name
      when :set
        op_site_id, op_key, op_value = op.args
        op_value if site_id == op_site_id && key == op_key
      when :getset
        op_site_id, op_key = op.args
        op_value = op.blk.call
        op_value if site_id == op_site_id && key == op_key && op_value == op.result
      end
    end
  end
end

RSpec.describe SiteCache do
  it "produces values from lookups and deletes that were previously inserted" do
    CachePathGenerator.complete(global_limit: 3, site_limit: 2) do |g|
      operations = g.generate_operations(upto: 4)
      last_op = g.generate_lookup

      site_id, key = last_op.args
      result = last_op.result

      expect(operations.values_inserted_at(site_id, key)).to include(result) if result
    end
  end

  describe "#getset" do
    it "caches nil" do
      cache = SiteCache.new(max_global_size: 2, max_size_per_site: 2)

      cache.getset("site", "test") { nil }
      cache.getset("site", "test") { raise }

      expect(cache.keys).to contain_exactly(%w[site test])
    end
  end

  describe "#keys" do
    it "reports all and only the keys that exist according to get/delete" do
      CachePathGenerator.complete(global_limit: 3, site_limit: 2) do |g|
        operations = g.generate_operations(upto: 4)
        keys = g.cache.keys
        last_op = g.generate_lookup

        site_id, key = last_op.args

        if keys.include?([site_id, key])
          result = last_op.result
          expect(result).not_to be(nil)
        else
          expect(result).to be(nil)
        end
      end
    end

    it "never has more than the global limit on the number of keys" do
      CachePathGenerator.complete(global_limit: 3, site_limit: 2) do |g|
        g.generate_operations(upto: 4)
        keys = g.cache.keys

        expect(keys.size).to be <= 3
      end
    end

    it "never has more than the per site limit on the number of keys" do
      CachePathGenerator.complete(global_limit: 3, site_limit: 2) do |g|
        g.generate_operations(upto: 4)

        g
          .cache
          .keys
          .group_by(&:first)
          .transform_values(&:size)
          .values
          .each { |s| expect(s).to be <= 2 }
      end
    end
  end

  describe "#clear" do
    it "causes future lookups to return nil" do
      CachePathGenerator.complete(global_limit: 3, site_limit: 2) do |g|
        g.generate_operations(upto: 4)
        g.cache.clear
        last_op = g.generate_lookup

        expect(last_op.result).to be(nil)
      end
    end
  end

  describe "#clear_site" do
    it "causes future lookups for that site to return nil" do
      CachePathGenerator.complete(global_limit: 3, site_limit: 2) do |g|
        site_id, key, value = g.insert_new
        g.generate_operations(upto: 3)
        g.cache.clear_site(site_id)
        last_op = g.generate_lookup_for_site(site_id)

        expect(last_op.result).to be(nil)
      end
    end

    it "doesn't clear other sites" do
      cache = SiteCache.new(max_global_size: 3, max_size_per_site: 2)
      site1_id = Object.new
      site2_id = Object.new
      key = Object.new
      value = Object.new

      cache.set(site1_id, key, value)
      cache.set(site2_id, key, value)

      cache.clear_site(site2_id)

      expect(cache.lookup(site1_id, key)).to be(value)
    end
  end
end
