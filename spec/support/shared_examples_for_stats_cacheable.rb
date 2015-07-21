shared_examples_for 'stats cachable' do
  describe 'fetch_cached_stats' do
    it 'returns the cached stats' do
      begin
        stats = { "visits" => 10 }
        $redis.set(described_class.stats_cache_key, stats.to_json)
        expect(described_class.fetch_cached_stats).to eq(stats)
      ensure
        $redis.del(described_class.stats_cache_key)
      end
    end

    it 'returns nil if no stats has been cached' do
      expect(described_class.fetch_cached_stats).to eq(nil)
    end
  end

  describe 'fetch_stats' do
    it 'has been implemented' do
      expect{ described_class.fetch_stats }.to_not raise_error
    end
  end
end
