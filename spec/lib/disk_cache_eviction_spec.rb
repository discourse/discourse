# frozen_string_literal: true

RSpec.describe DiskCacheEviction do
  let(:cache_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(cache_dir) }

  def create_files(count, prefix: "file", age_offset: 0)
    count.times.map do |i|
      path = File.join(cache_dir, "#{prefix}_#{i}.tmp")
      File.write(path, "data_#{i}")
      FileUtils.touch(path, mtime: Time.now - (age_offset + count - i).hours)
      path
    end
  end

  describe ".evict" do
    it "does nothing when file count is under the limit" do
      create_files(3)
      described_class.evict(dir: cache_dir, max_entries: 5, evict_count: 2)
      expect(Dir.glob(File.join(cache_dir, "*")).length).to eq(3)
    end

    it "does nothing when file count equals the limit" do
      create_files(5)
      described_class.evict(dir: cache_dir, max_entries: 5, evict_count: 2)
      expect(Dir.glob(File.join(cache_dir, "*")).length).to eq(5)
    end

    it "evicts the oldest files when over the limit" do
      old_files = create_files(3, prefix: "old", age_offset: 10)
      new_files = create_files(3, prefix: "new", age_offset: 0)

      described_class.evict(dir: cache_dir, max_entries: 5, evict_count: 2)

      expect(File.exist?(old_files[0])).to eq(false)
      expect(File.exist?(old_files[1])).to eq(false)
      expect(File.exist?(old_files[2])).to eq(true)
      new_files.each { |f| expect(File.exist?(f)).to eq(true) }
    end

    it "handles files vanishing between glob and stat" do
      files = create_files(6, prefix: "race")
      vanishing = files.first

      # Simulate race: file is in glob results but gone when File.mtime is called
      File.stubs(:mtime).with(anything).returns(Time.now)
      File.stubs(:mtime).with(vanishing).raises(Errno::ENOENT)

      expect {
        described_class.evict(dir: cache_dir, max_entries: 5, evict_count: 2)
      }.not_to raise_error
    end
  end
end
