# frozen_string_literal: true

RSpec.describe BackupRestore::Creator, type: :multisite do
  it "uses the originating database while archiving uploads alongside the dump" do
    creator = described_class.new(nil)
    creator.instance_variable_set(:@current_db, "second")
    creator.instance_variable_set(:@with_uploads, true)
    creator.stubs(:dump_public_schema)
    creator.stubs(:add_path_to_archive)
    observations = Queue.new
    creator.define_singleton_method(:add_local_uploads_to_archive) do
      observations << RailsMultisite::ConnectionManagement.current_db
    end

    Timeout.timeout(10) { creator.send(:populate_archive, Object.new) }

    expect(observations.pop).to eq("second")
  end

  it "downloads concurrently with the originating database context and waits for completion" do
    creator = described_class.new(nil)
    creator.instance_variable_set(:@s3_store, stub(s3_helper: stub(object: nil)))
    GlobalSetting.stubs(:backup_s3_download_concurrency).returns(2)
    barrier = Concurrent::CyclicBarrier.new(2)
    observations = Queue.new
    database = "second"
    creator.instance_variable_set(:@current_db, database)
    creator.define_singleton_method(:process_upload_group) do |group|
      raise "Workers did not start" unless barrier.wait(5)
      observations << [group, Thread.current, RailsMultisite::ConnectionManagement.current_db]
    end

    Timeout.timeout(10) { creator.send(:download_upload_groups, [1, 2]) }

    results = 2.times.map { observations.pop }
    expect(results.map(&:first).sort).to eq([1, 2])
    expect(results.map { |result| result[1] }.uniq.size).to eq(2)
    expect(results.map { |result| result[2] }.uniq).to eq([database])
    expect(results.all? { |result| !result[1].alive? }).to eq(true)
  end
end
