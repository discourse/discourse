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
    it "only moves files from the uploads directory" do
      uploads_dir = "#{store.public_dir}#{store.relative_base_url}"
      FileUtils.mkdir_p("#{uploads_dir}/original")

      Tempfile.create("remove_upload", store.public_dir) do |file|
        [
          "#{store.relative_base_url}/../../../#{File.basename(file)}",
          "#{store.relative_base_url}/original/..",
        ].each do |url|
          upload.url = url
          store.remove_upload(upload)
        end

        expect(File.exist?(file)).to eq(true)
        expect(Dir.exist?("#{uploads_dir}/original")).to eq(true)
      end
    end

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

  describe "#path_for" do
    it "returns the path of uploads and seeded images" do
      upload.url = "/#{upload_path}/original/1X/#{upload.sha1}.png"
      expect(store.path_for(upload)).to eq("#{store.public_dir}#{upload.url}")

      upload.url = "/images/avatar.png"
      expect(store.path_for(upload)).to eq("#{store.public_dir}/images/avatar.png")

      set_subfolder "/forum"
      upload.url = "/forum/#{upload_path}/original/1X/#{upload.sha1}.png"
      expect(store.path_for(upload)).to eq("#{store.public_dir}#{upload.url}")
    end

    it "returns nil for urls outside of the store directories" do
      [
        "//cdn.example.com/original/1X/#{upload.sha1}.png",
        "/#{upload_path}/../other/original/1X/#{upload.sha1}.png",
        "/#{upload_path}-other/original/1X/#{upload.sha1}.png",
      ].each do |url|
        upload.url = url
        expect(store.path_for(upload)).to eq(nil), url
      end
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
