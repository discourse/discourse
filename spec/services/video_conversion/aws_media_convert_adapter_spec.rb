# frozen_string_literal: true

require "aws-sdk-mediaconvert"
require "aws-sdk-s3" # so Aws::S3::Object::Acl is loaded

# Dummy context struct for verifying double
FakeContext = Struct.new(:request_id)

RSpec.describe VideoConversion::AwsMediaConvertAdapter do
  fab!(:user)

  before(:each) do
    extensions = SiteSetting.authorized_extensions.split("|")
    SiteSetting.authorized_extensions = (extensions | ["mp4"]).join("|")
  end

  let!(:upload) { Fabricate(:video_upload, user: user) }
  fab!(:post) { Fabricate(:post, user: user) }
  let(:options) { { quality: "high" } }
  let(:adapter) { described_class.new(upload, options) }
  let(:mediaconvert_client) { instance_double(Aws::MediaConvert::Client) }
  let(:s3_store) { instance_double(FileStore::S3Store) }
  let(:s3_object) { instance_double(Aws::S3::Object) }
  let(:s3_bucket) { "test-bucket" }
  let(:s3_region) { "us-east-1" }
  let(:new_sha1) { "a" * 40 } # A valid SHA1 is 40 characters
  let(:mediaconvert_job) { instance_double(Aws::MediaConvert::Types::Job) }
  let(:mediaconvert_job_response) do
    instance_double(Aws::MediaConvert::Types::CreateJobResponse, job: mediaconvert_job)
  end
  let(:mediaconvert_context) { instance_double(FakeContext, request_id: "test-request-id") }
  let(:post_relation) { instance_double(ActiveRecord::Relation) }
  # The ACL resource class is Aws::S3::ObjectAcl in aws-sdk-s3 v3
  let(:acl_object) { instance_double(Aws::S3::ObjectAcl) }

  before do
    upload.update!(sha1: new_sha1)

    allow(SecureRandom).to receive(:hex).with(20).and_return(new_sha1)

    allow(SiteSetting).to receive(:video_conversion_enabled).and_return(true)
    allow(SiteSetting).to receive(:mediaconvert_role_arn).and_return(
      "arn:aws:iam::123456789012:role/MediaConvertRole",
    )
    allow(SiteSetting).to receive(:mediaconvert_endpoint).and_return(
      "https://mediaconvert.endpoint",
    )
    allow(SiteSetting.Upload).to receive(:s3_upload_bucket).and_return(s3_bucket)
    allow(SiteSetting).to receive(:s3_region).and_return(s3_region)
    allow(SiteSetting).to receive(:s3_access_key_id).and_return("test-key")
    allow(SiteSetting).to receive(:s3_secret_access_key).and_return("test-secret")
    allow(SiteSetting).to receive(:s3_use_acls).and_return(true)

    allow(Aws::MediaConvert::Client).to receive(:new).and_return(mediaconvert_client)
    allow(FileStore::S3Store).to receive(:new).and_return(s3_store)
    allow(s3_store).to receive(:s3_bucket).and_return(s3_bucket)
    allow(s3_store).to receive(:object_from_path).and_return(s3_object)
    allow(s3_object).to receive(:exists?).and_return(true)
    allow(s3_object).to receive(:size).and_return(1024)
    allow(s3_object).to receive(:acl).and_return(acl_object)
    allow(acl_object).to receive(:put).with(acl: "public-read").and_return(true)

    allow(UploadReference).to receive(:where).with(
      upload_id: upload.id,
      target_type: "Post",
    ).and_return(instance_double(ActiveRecord::Relation, pluck: [post.id]))

    allow(Post).to receive(:where).with(id: [post.id]).and_return(post_relation)
    allow(post_relation).to receive(:find_each).and_yield(post)
    allow(post).to receive(:rebake!)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:info)
    allow(Discourse).to receive(:warn_exception)
    allow(Jobs).to receive(:enqueue_in)
    allow(OptimizedVideo).to receive(:create_for)
  end

  describe "#convert" do
    let(:output_path) do
      "/uploads/default/test_#{ENV["TEST_ENV_NUMBER"].presence || "0"}/original/1X/#{new_sha1}"
    end
    let(:job_id) { "job-123" }

    before { allow(Jobs).to receive(:enqueue_in) }

    context "when settings are valid" do
      before do
        upload.update!(
          url: "//#{s3_bucket}.s3.#{s3_region}.amazonaws.com/uploads/default/original/test.mp4",
          original_filename: "test.mp4",
        )

        allow(mediaconvert_job).to receive(:id).and_return(job_id)
        allow(mediaconvert_client).to receive(:create_job).and_return(mediaconvert_job_response)
      end

      it "creates a MediaConvert job and enqueues status check" do
        input_path = "s3://#{s3_bucket}/uploads/default/original/test.mp4"
        expected_settings = described_class.build_conversion_settings(input_path, output_path)

        expected_job_params = {
          role: SiteSetting.mediaconvert_role_arn,
          settings: expected_settings,
          status_update_interval: "SECONDS_10",
          user_metadata: {
            "upload_id" => upload.id.to_s,
            "new_sha1" => new_sha1,
            "output_path" => output_path,
          },
        }

        adapter.convert

        expect(mediaconvert_client).to have_received(:create_job).with(expected_job_params)

        expected_args = {
          adapter_type: "aws_mediaconvert",
          job_id: job_id,
          new_sha1: new_sha1,
          output_path: output_path,
          original_filename: upload.original_filename,
          upload_id: upload.id,
          user_id: upload.user_id,
        }

        expect(Jobs).to have_received(:enqueue_in).with(
          30.seconds,
          :check_video_conversion_status,
          expected_args,
        )

        expect(adapter.convert).to be true
      end

      it "handles MediaConvert service errors" do
        error = Aws::MediaConvert::Errors::ServiceError.new(mediaconvert_context, "Test error")
        allow(error).to receive(:code).and_return("InvalidParameter")
        allow(mediaconvert_client).to receive(:create_job).and_raise(error)

        adapter.convert

        expect(Discourse).to have_received(:warn_exception).with(
          error,
          message: "MediaConvert job creation failed",
          env: {
            upload_id: upload.id,
          },
        )
        expect(adapter.convert).to be false
      end

      it "handles unexpected errors" do
        error = StandardError.new("Unexpected error")
        allow(mediaconvert_client).to receive(:create_job).and_raise(error)

        adapter.convert

        expect(Discourse).to have_received(:warn_exception).with(
          error,
          message: "Unexpected error in MediaConvert job creation",
          env: {
            upload_id: upload.id,
          },
        )
        expect(adapter.convert).to be false
      end
    end

    context "when settings are invalid" do
      before { allow(SiteSetting).to receive(:video_conversion_enabled).and_return(false) }

      it "returns false" do
        expect(adapter.convert).to be false
      end
    end

    context "with invalid upload URL" do
      before { upload.update!(url: "//wrong-bucket.s3.region.amazonaws.com/path/to/file") }

      it "returns false and logs error" do
        adapter.convert
        expect(Rails.logger).to have_received(:error).with(
          "Invalid parameters for upload #{upload.id}: Upload URL domain for upload ID #{upload.id} does not contain expected bucket name: #{s3_bucket}",
        )
        expect(adapter.convert).to be false
      end
    end
  end

  describe "#check_status" do
    let(:job_id) { "job-123" }

    context "when job is complete" do
      before do
        allow(mediaconvert_job).to receive(:status).and_return("COMPLETE")
        allow(mediaconvert_client).to receive(:get_job).and_return(mediaconvert_job_response)
      end

      it "returns :complete" do
        expect(adapter.check_status(job_id)).to eq(:complete)
      end
    end

    context "when job has error" do
      before do
        allow(mediaconvert_job).to receive(:status).and_return("ERROR")
        allow(mediaconvert_job).to receive(:error_code).and_return("1517")
        allow(mediaconvert_job).to receive(:error_message).and_return("S3 Write Error")
        allow(mediaconvert_job).to receive(:settings).and_return(nil)
        allow(mediaconvert_client).to receive(:get_job).and_return(mediaconvert_job_response)
      end

      it "returns :error and logs the error" do
        adapter.check_status(job_id)
        expect(Rails.logger).to have_received(:error).with(
          /MediaConvert job #{job_id} failed\. Error Code: 1517, Error Message: S3 Write Error, Upload ID: #{upload.id}/,
        )
        expect(adapter.check_status(job_id)).to eq(:error)
      end
    end

    context "when job is in progress" do
      before do
        allow(mediaconvert_job).to receive(:status).and_return("PROGRESSING")
        allow(mediaconvert_client).to receive(:get_job).and_return(mediaconvert_job_response)
      end

      it "returns :pending" do
        expect(adapter.check_status(job_id)).to eq(:pending)
      end
    end

    context "when job has unexpected status" do
      before do
        allow(mediaconvert_job).to receive(:status).and_return("UNKNOWN")
        allow(mediaconvert_client).to receive(:get_job).and_return(mediaconvert_job_response)
      end

      it "returns :error and logs warning" do
        adapter.check_status(job_id)
        expect(Rails.logger).to have_received(:warn).with(/Unexpected MediaConvert job status/)
        expect(adapter.check_status(job_id)).to eq(:error)
      end
    end
  end

  describe "#handle_completion" do
    let(:job_id) { "job-123" }
    let(:output_path) { "optimized/videos/test-sha1" }
    let(:expected_url) do
      "//#{s3_bucket}.s3.dualstack.#{s3_region}.amazonaws.com/#{output_path}.mp4"
    end

    it "creates optimized video record and rebakes posts" do
      allow(s3_object).to receive(:exists?).and_return(true)
      allow(s3_object).to receive(:size).and_return(1024)
      allow(OptimizedVideo).to receive(:create_for).and_return(true)

      adapter.handle_completion(job_id, output_path, new_sha1)

      expect(s3_object).to have_received(:exists?)
      expect(s3_object).to have_received(:size)
      expect(OptimizedVideo).to have_received(:create_for).with(
        upload,
        "video_converted.mp4",
        upload.user_id,
        {
          extension: "mp4",
          filesize: 1024,
          sha1: new_sha1,
          url: expected_url,
          adapter: "aws_mediaconvert",
        },
      )
      expect(post).to have_received(:rebake!)
      expect(Rails.logger).to have_received(:info).with(/Rebaking post #{post.id}/)

      expect(adapter.handle_completion(job_id, output_path, new_sha1)).to be true
    end

    context "when S3 object doesn't exist" do
      before { allow(s3_object).to receive(:exists?).and_return(false) }

      it "returns false" do
        expect(adapter.handle_completion(job_id, output_path, new_sha1)).to be false
      end
    end

    context "when optimized video creation fails" do
      before do
        allow(s3_object).to receive(:exists?).and_return(true)
        allow(OptimizedVideo).to receive(:create_for).and_return(false)
      end

      it "returns false and logs error" do
        adapter.handle_completion(job_id, output_path, new_sha1)
        expect(Rails.logger).to have_received(:error).with(/Failed to create OptimizedVideo record/)
        expect(adapter.handle_completion(job_id, output_path, new_sha1)).to be false
      end
    end

    context "when an error occurs" do
      let(:error) { StandardError.new("Test error") }

      before do
        allow(s3_object).to receive(:exists?).and_return(true)
        allow(s3_object).to receive(:size).and_return(1024)
        allow(OptimizedVideo).to receive(:create_for).and_raise(error)
      end

      it "returns false and logs error" do
        adapter.handle_completion(job_id, output_path, new_sha1)
        expect(Discourse).to have_received(:warn_exception).with(
          error,
          message: "Error in video processing completion",
          env: {
            upload_id: upload.id,
            job_id: job_id,
          },
        )
        expect(adapter.handle_completion(job_id, output_path, new_sha1)).to be false
      end
    end

    context "when ACL update is disabled" do
      before do
        allow(SiteSetting).to receive(:s3_use_acls).and_return(false)
        allow(s3_object).to receive(:exists?).and_return(true)
        allow(OptimizedVideo).to receive(:create_for).and_return(true)
      end

      it "skips ACL update and completes successfully" do
        adapter.handle_completion(job_id, output_path, new_sha1)
        expect(s3_object).not_to have_received(:acl)
        expect(adapter.handle_completion(job_id, output_path, new_sha1)).to be true
      end
    end
  end
end
