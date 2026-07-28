# frozen_string_literal: true

require "file_store/local_store"

RSpec.describe FileStore::LocalStore do
  let(:store) { FileStore::LocalStore.new }

  fab!(:upload)
  let(:uploaded_file) { file_from_fixtures("logo.png") }
  let(:upload_path) { Discourse.store.upload_path }

  fab!(:optimized_image)

  describe "#store_upload" do
    it "returns a relative url" do
      store.expects(:copy_file)
      expect(store.store_upload(uploaded_file, upload)).to match(
        %r{/#{upload_path}/original/.+#{upload.sha1}\.png},
      )
    end
  end

  describe "#store_optimized_image" do
    it "returns a relative url" do
      store.expects(:copy_file)
      expect(store.store_optimized_image({}, optimized_image)).to match(
        %r{/#{upload_path}/optimized/.+#{optimized_image.upload.sha1}_#{OptimizedImage::VERSION}_100x200\.png},
      )
    end
  end

  describe "#remove_upload" do
    it "does not delete non uploaded" do
      FileUtils.expects(:mkdir_p).never
      store.remove_upload(upload)
    end

    it "moves the file to the tombstone" do
      upload =
        UploadCreator.new(file_from_fixtures("smallest.png"), "smallest.png").create_for(
          Fabricate(:user).id,
        )

      path = store.path_for(upload)
      mtime = File.mtime(path)

      sleep 0.01 # Delay a little for mtime to be updated
      store.remove_upload(upload)
      tombstone_path = path.sub("/uploads/", "/uploads/tombstone/")

      expect(File.exist?(tombstone_path)).to eq(true)
      expect(File.mtime(tombstone_path)).to_not eq(mtime)
    ensure
      [path, tombstone_path].each { |file_path| File.delete(file_path) if File.exist?(file_path) }
    end
  end

  describe "#remove_optimized_image" do
    it "moves the file to the tombstone" do
      upload =
        UploadCreator.new(file_from_fixtures("smallest.png"), "smallest.png").create_for(
          Fabricate(:user).id,
        )

      upload.create_thumbnail!(1, 1)
      upload.reload

      optimized_image = upload.thumbnail(1, 1)
      path = store.path_for(optimized_image)

      store.remove_optimized_image(optimized_image)
      tombstone_path = path.sub("/uploads/", "/uploads/tombstone/")

      expect(File.exist?(tombstone_path)).to eq(true)
    ensure
      [path, tombstone_path].each { |file_path| File.delete(file_path) if File.exist?(file_path) }
    end
  end

  describe "#purge_tombstone" do
    let(:tombstone_dir) { Dir.mktmpdir }

    around do |example|
      original_timezone = ENV["TZ"]
      ENV["TZ"] = "America/New_York"
      Time.use_zone("America/New_York") { example.run }
    ensure
      ENV["TZ"] = original_timezone
    end

    before { store.stubs(:tombstone_dir).returns(tombstone_dir) }
    after { FileUtils.rm_rf(tombstone_dir) }

    it "deletes only expired regular files throughout the tombstone" do
      hidden_directory = File.join(tombstone_dir, ".hidden", "nested")
      FileUtils.mkdir_p(hidden_directory)
      expired_file = File.join(hidden_directory, "expired.png")
      boundary_file = File.join(tombstone_dir, "boundary.png")
      newer_file = File.join(tombstone_dir, "newer.png")
      symlink = File.join(tombstone_dir, "link.png")
      [expired_file, boundary_file, newer_file].each { |path| File.write(path, "image") }
      File.symlink(expired_file, symlink)
      current_time = Time.now
      boundary_days =
        (1..365).find do |days|
          (current_time - days.days).to_i != (current_time - days * 1.day.to_i).to_i
        end
      grace_period = boundary_days - 1
      expired_time = current_time - (boundary_days + 1) * 1.day.to_i
      boundary_time = current_time - boundary_days * 1.day.to_i
      File.utime(expired_time, expired_time, expired_file)
      File.utime(boundary_time, boundary_time, boundary_file)
      File.utime(boundary_time + 1.minute, boundary_time + 1.minute, newer_file)

      store.purge_tombstone(grace_period)

      expect(
        [
          File.exist?(expired_file),
          File.exist?(boundary_file),
          File.exist?(newer_file),
          File.symlink?(symlink),
        ],
      ).to eq([false, false, true, true])
    end

    it "continues processing siblings and reports entry failures after traversal" do
      skip "requires an unprivileged process" if Process.uid.zero?

      blocked_directory = File.join(tombstone_dir, "blocked")
      FileUtils.mkdir_p(blocked_directory)
      File.write(File.join(blocked_directory, "file.png"), "image")
      deletable_file = File.join(tombstone_dir, "deletable.png")
      File.write(deletable_file, "image")
      expired_time = Time.now - 2 * 1.day.to_i
      File.utime(expired_time, expired_time, deletable_file)
      FileUtils.chmod(0, blocked_directory)

      expect { store.purge_tombstone(0) }.to raise_error(/Permission denied/)
      expect(File.exist?(deletable_file)).to eq(false)
    ensure
      FileUtils.chmod(0o700, blocked_directory) if Dir.exist?(blocked_directory)
    end
  end

  describe "#has_been_uploaded?" do
    it "identifies relatives urls" do
      expect(store.has_been_uploaded?("/#{upload_path}/42/0123456789ABCDEF.jpg")).to eq(true)
    end

    it "identifies local urls" do
      Discourse.stubs(:base_url_no_prefix).returns("http://discuss.site.com")
      expect(
        store.has_been_uploaded?("http://discuss.site.com/#{upload_path}/42/0123456789ABCDEF.jpg"),
      ).to eq(true)
      expect(
        store.has_been_uploaded?("//discuss.site.com/#{upload_path}/42/0123456789ABCDEF.jpg"),
      ).to eq(true)
    end

    it "identifies local urls when using a CDN" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      expect(
        store.has_been_uploaded?("http://my.cdn.com/#{upload_path}/42/0123456789ABCDEF.jpg"),
      ).to eq(true)
      expect(store.has_been_uploaded?("//my.cdn.com/#{upload_path}/42/0123456789ABCDEF.jpg")).to eq(
        true,
      )
    end

    it "does not match dummy urls" do
      expect(
        store.has_been_uploaded?("http://domain.com/#{upload_path}/42/0123456789ABCDEF.jpg"),
      ).to eq(false)
      expect(store.has_been_uploaded?("//domain.com/#{upload_path}/42/0123456789ABCDEF.jpg")).to eq(
        false,
      )
    end
  end

  describe "#absolute_base_url" do
    it "is present" do
      expect(store.absolute_base_url).to eq("http://test.localhost/#{upload_path}")
    end

    it "supports subfolder" do
      set_subfolder "/forum"
      expect(store.absolute_base_url).to eq("http://test.localhost/forum/#{upload_path}")
    end
  end

  describe "#relative_base_url" do
    it "is present" do
      expect(store.relative_base_url).to eq("/#{upload_path}")
    end

    it "supports subfolder" do
      set_subfolder "/forum"
      expect(store.relative_base_url).to eq("/forum/#{upload_path}")
    end
  end

  it "is internal" do
    expect(store.internal?).to eq(true)
    expect(store.external?).to eq(false)
  end

  describe "#get_path_for" do
    it "returns the correct path" do
      expect(
        store.get_path_for("original", upload.id, upload.sha1, ".#{upload.extension}"),
      ).to match(%r{/#{upload_path}/original/.+#{upload.sha1}\.png})
    end
  end

  describe "#get_path_for_upload" do
    it "returns the correct path" do
      expect(store.get_path_for_upload(upload)).to match(
        %r{/#{upload_path}/original/.+#{upload.sha1}\.png},
      )
    end
  end

  describe "#get_path_for_optimized_image" do
    it "returns the correct path" do
      expect(store.get_path_for_optimized_image(optimized_image)).to match(
        %r{/#{upload_path}/optimized/.+#{optimized_image.upload.sha1}_#{OptimizedImage::VERSION}_100x200\.png},
      )
    end
  end
end
