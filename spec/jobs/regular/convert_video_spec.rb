# frozen_string_literal: true

RSpec.describe Jobs::ConvertVideo do
  subject(:job) { described_class.new }

  before(:each) do
    extensions = SiteSetting.authorized_extensions.split("|")
    SiteSetting.authorized_extensions = (extensions | ["mp4"]).join("|")
  end

  let!(:upload) { Fabricate(:video_upload) }
  let(:args) { { upload_id: upload.id } }

  describe "#execute" do
    it "does nothing if upload_id is blank" do
      expect { job.execute({}) }.not_to change { OptimizedVideo.count }
    end

    it "does nothing if upload does not exist" do
      expect { job.execute(upload_id: -1) }.not_to change { OptimizedVideo.count }
    end

    it "does nothing if optimized video already exists" do
      Fabricate(:optimized_video, upload: upload)
      expect { job.execute(args) }.not_to change { OptimizedVideo.count }
    end

    context "when upload url is blank" do
      before do
        upload.stubs(:url).returns("")
        Upload.stubs(:find_by).with(id: upload.id).returns(upload)
        Jobs::ConvertVideo.jobs.clear
      end

      it "retries the job if under max retries" do
        expect { job.execute(args.merge(retry_count: 0)) }.to change {
          Jobs::ConvertVideo.jobs.size
        }.by(1)

        enqueued_job = Jobs::ConvertVideo.jobs.last
        expect(enqueued_job["args"].first["retry_count"]).to eq(1)
      end

      it "logs error and stops retrying after max retries" do
        expect {
          job.execute(args.merge(retry_count: Jobs::ConvertVideo::MAX_RETRIES))
        }.not_to change { Jobs::ConvertVideo.jobs.size }
        Rails
          .logger
          .expects(:error)
          .with(
            "Upload #{upload.id} URL remained blank after #{Jobs::ConvertVideo::MAX_RETRIES} retries when optimizing video",
          )
        job.execute(args.merge(retry_count: Jobs::ConvertVideo::MAX_RETRIES))
      end
    end

    context "when upload has a url" do
      let(:adapter) { mock }

      before do
        VideoConversion::AdapterFactory.stubs(:get_adapter).with(upload).returns(adapter)
        Upload.stubs(:find_by).with(id: upload.id).returns(upload)
      end

      it "converts the video using the adapter" do
        adapter.expects(:convert).returns(true)
        job.execute(args)
      end

      it "logs error if conversion fails" do
        adapter.expects(:convert).returns(false)
        Rails.logger.expects(:error).with("Video conversion failed for upload #{upload.id}")
        job.execute(args)
      end
    end
  end
end
