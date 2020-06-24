# frozen_string_literal: true

require 'rails_helper'

describe DiscourseRedis do
  it "ignore_readonly returns nil from a pure exception" do
    result = DiscourseRedis.ignore_readonly { raise Redis::CommandError.new("READONLY") }
    expect(result).to eq(nil)
  end

  describe 'redis commands' do
    let(:raw_redis) { Redis.new(DiscourseRedis.config) }

    before do
      raw_redis.flushdb
    end

    after do
      raw_redis.flushdb
    end

    describe 'when namespace is enabled' do
      let(:redis) { DiscourseRedis.new }

      it 'should append namespace to the keys' do
        raw_redis.set('default:key', 1)
        raw_redis.set('test:key2', 1)

        expect(redis.keys).to include('key')
        expect(redis.keys).to_not include('key2')
        expect(redis.scan_each.to_a).to eq(['key'])

        redis.scan_each.each do |key|
          expect(key).to eq('key')
        end

        redis.del('key')

        expect(raw_redis.get('default:key')).to eq(nil)
        expect(redis.scan_each.to_a).to eq([])

        raw_redis.set('default:key1', '1')
        raw_redis.set('default:key2', '2')

        expect(redis.mget('key1', 'key2')).to eq(['1', '2'])
        expect(redis.scan_each.to_a).to contain_exactly('key1', 'key2')
      end
    end

    describe 'when namespace is disabled' do
      let(:redis) { DiscourseRedis.new(nil, namespace: false) }

      it 'should not append any namespace to the keys' do
        raw_redis.set('default:key', 1)
        raw_redis.set('test:key2', 1)

        expect(redis.keys).to include('default:key', 'test:key2')

        redis.del('key')

        expect(raw_redis.get('key')).to eq(nil)

        raw_redis.set('key1', '1')
        raw_redis.set('key2', '2')

        expect(redis.mget('key1', 'key2')).to eq(['1', '2'])
      end

      it 'should noop a readonly redis' do
        expect(Discourse.recently_readonly?).to eq(false)

        redis.without_namespace
          .expects(:set)
          .raises(Redis::CommandError.new("READONLY"))

        redis.set('key', 1)

        expect(Discourse.recently_readonly?).to eq(true)
      end
    end
  end
end
