# frozen_string_literal: true

RSpec.describe VideoConversion::BaseAdapter do
  before(:each) do
    extensions = SiteSetting.authorized_extensions.split("|")
    SiteSetting.authorized_extensions = (extensions | ["mp4"]).join("|")
  end

  let(:upload) { Fabricate(:video_upload) }
  let(:options) { { quality: "high" } }
  let(:adapter) { described_class.new(upload, options) }

  describe "#initialize" do
    it "sets the upload and options" do
      expect(adapter.instance_variable_get(:@upload)).to eq(upload)
      expect(adapter.instance_variable_get(:@options)).to eq(options)
    end
  end

  describe "#convert" do
    it "raises NotImplementedError" do
      expect { adapter.convert }.to raise_error(
        NotImplementedError,
        "#{described_class} must implement #convert",
      )
    end
  end

  describe "#check_status" do
    it "raises NotImplementedError" do
      expect { adapter.check_status("job-123") }.to raise_error(
        NotImplementedError,
        "#{described_class} must implement #check_status",
      )
    end
  end

  describe "#handle_completion" do
    it "raises NotImplementedError" do
      expect {
        adapter.handle_completion("job-123", "/path/to/output.mp4", "new-sha1")
      }.to raise_error(NotImplementedError, "#{described_class} must implement #handle_completion")
    end
  end

  describe "#create_optimized_video_record" do
    let(:output_path) { "/path/to/output.mp4" }
    let(:new_sha1) { "new-sha1-hash" }
    let(:filesize) { 1024 }
    let(:url) { "//bucket.s3.region.amazonaws.com/optimized/videos/new-sha1-hash.mp4" }

    before { allow(OptimizedVideo).to receive(:create_for) }

    context "with adapter that defines ADAPTER_NAME" do
      let(:adapter_name) { "test_adapter_#{SecureRandom.hex(4)}" }
      let(:test_adapter_class) do
        adapter_name_const = adapter_name
        Class.new(VideoConversion::BaseAdapter) do
          const_set(:ADAPTER_NAME, adapter_name_const)
          def self.name
            "TestAdapter"
          end
        end
      end
      let(:adapter) { test_adapter_class.new(upload) }

      it "creates an optimized video record with correct attributes" do
        adapter.send(:create_optimized_video_record, output_path, new_sha1, filesize, url)

        expect(OptimizedVideo).to have_received(:create_for).with(
          upload,
          "video_converted.mp4",
          upload.user_id,
          filesize: filesize,
          sha1: new_sha1,
          url: url,
          extension: "mp4",
          adapter: adapter_name,
        )
      end

      it "handles filenames with multiple extensions" do
        upload.update!(original_filename: "video.original.mp4")

        adapter.send(:create_optimized_video_record, output_path, new_sha1, filesize, url)

        expect(OptimizedVideo).to have_received(:create_for).with(
          upload,
          "video.original_converted.mp4",
          upload.user_id,
          filesize: filesize,
          sha1: new_sha1,
          url: url,
          extension: "mp4",
          adapter: adapter_name,
        )
      end
    end
  end
end
