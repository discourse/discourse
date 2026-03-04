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
    allow(SiteSetting).to receive(:mediaconvert_output_subdirectory).and_return("transcoded")
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

    post_upload_ref_relation = instance_double(ActiveRecord::Relation)
    post_subquery = instance_double(ActiveRecord::Relation)
    chat_upload_ref_relation = instance_double(ActiveRecord::Relation)
    chat_subquery = instance_double(ActiveRecord::Relation)

    allow(UploadReference).to receive(:where).with(
      upload_id: upload.id,
      target_type: "Post",
    ).and_return(post_upload_ref_relation)
    allow(post_upload_ref_relation).to receive(:select).with(:target_id).and_return(post_subquery)

    allow(UploadReference).to receive(:where).with(
      upload_id: upload.id,
      target_type: "ChatMessage",
    ).and_return(chat_upload_ref_relation)
    allow(chat_upload_ref_relation).to receive(:select).with(:target_id).and_return(chat_subquery)
    allow(chat_subquery).to receive(:exists?).and_return(false)

    allow(Post).to receive(:where) do |args|
      # Accept either array of IDs or subquery relation
      if args[:id].is_a?(Array)
        post_relation if args[:id] == [post.id]
      elsif args[:id] == post_subquery
        post_relation
      end
    end.and_return(post_relation)
    allow(post_relation).to receive(:find_each).and_yield(post)
    allow(post).to receive(:rebake!)

    # Stub Chat::Message queries for chat message video conversion support
    chat_message_relation = instance_double(ActiveRecord::Relation)
    if defined?(Chat::Message)
      allow(Chat::Message).to receive(:where).with(id: []).and_return(chat_message_relation)
      allow(chat_message_relation).to receive(:includes).and_return(chat_message_relation)
      allow(chat_message_relation).to receive(:find_each)
    end
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
        # MediaConvert automatically adds .mp4 extension, so we pass filename without extension
        temp_output_filename = new_sha1
        expected_settings =
          described_class.build_conversion_settings(input_path, temp_output_filename)
        # Verify the destination includes the subdirectory with simple filename (no .mp4)
        # MediaConvert will add .mp4 automatically
        destination =
          expected_settings[:output_groups][0][:output_group_settings][:file_group_settings][
            :destination
          ]
        expected_destination_path = File.join("transcoded", temp_output_filename)
        expect(destination).to eq("s3://#{s3_bucket}/#{expected_destination_path}")

        expected_job_params = {
          role: SiteSetting.mediaconvert_role_arn,
          settings: expected_settings,
          status_update_interval: "SECONDS_10",
          user_metadata: {
            "upload_id" => upload.id.to_s,
            "new_sha1" => new_sha1,
          },
        }

        adapter.convert

        expect(mediaconvert_client).to have_received(:create_job).with(expected_job_params)

        expected_args = {
          adapter_type: "aws_mediaconvert",
          job_id: job_id,
          new_sha1: new_sha1,
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
    let(:temp_path) { "transcoded/#{new_sha1}.mp4" }
    let(:final_path) { "original/1X/#{new_sha1}.mp4" }
    let(:s3_helper) { instance_double(S3Helper) }
    let(:s3_client) { instance_double(Aws::S3::Client) }
    let(:s3_resource) { instance_double(Aws::S3::Resource) }
    let(:bucket_name) { s3_bucket }
    let(:source_bucket) { instance_double(Aws::S3::Bucket) }
    let(:source_s3_object) { instance_double(Aws::S3::Object) }
    let(:destination_s3_object) { instance_double(Aws::S3::Object) }
    let(:copy_response) { instance_double(Aws::S3::Types::CopyObjectOutput) }
    let(:copy_result) { instance_double(Aws::S3::Types::CopyObjectResult, etag: '"etag123"') }

    before do
      allow(s3_store).to receive(:s3_helper).and_return(s3_helper)
      allow(s3_store).to receive(:default_s3_options).and_return({})
      allow(s3_store).to receive(:absolute_base_url).and_return(
        "//#{s3_bucket}.s3.dualstack.#{s3_region}.amazonaws.com",
      )

      # Mock s3_helper.object for find_temp_file
      allow(s3_helper).to receive(:object).with(temp_path).and_return(source_s3_object)
      allow(source_s3_object).to receive(:exists?).and_return(true)
      allow(source_s3_object).to receive(:size).and_return(1024)

      # Mock s3_helper.copy - it returns [destination_path, etag]
      # The destination path will have multisite prefix if in multisite mode
      # Use a flexible matcher since the exact path format depends on multisite configuration
      allow(s3_helper).to receive(:copy) do |source, dest, options: {}|
        if source == temp_path && dest.include?(final_path)
          # Return the destination path as-is (it may have multisite prefix)
          [dest, "etag123"]
        else
          raise "Unexpected copy call: source=#{source}, dest=#{dest}"
        end
      end

      # Mock s3_helper.object for destination verification (flexible path matching)
      allow(s3_helper).to receive(:object) do |path|
        if path == temp_path
          source_s3_object
        elsif path.include?(final_path)
          destination_s3_object
        else
          source_s3_object
        end
      end
      allow(destination_s3_object).to receive(:exists?).and_return(true)

      # Mock s3_helper.remove for remove_temp_file
      allow(s3_helper).to receive(:remove).with(temp_path, false)
    end

    # Helper to get S3 path with multisite prefix if in multisite mode (matching get_s3_path logic)
    def get_s3_path_for_test(path)
      if Rails.configuration.multisite
        multisite_prefix = File.join("uploads", RailsMultisite::ConnectionManagement.current_db)
        multisite_prefix = "#{multisite_prefix}/"
        # Prevent double-prepending if path already includes the multisite prefix
        return path if path.start_with?(multisite_prefix)
        File.join(multisite_prefix, path)
      else
        path
      end
    end

    it "copies file from subdirectory to final location, deletes temp file, and creates optimized video record" do
      optimized_video_instance = instance_double(OptimizedVideo)
      allow(OptimizedVideo).to receive(:create_for).and_return(optimized_video_instance)
      allow(s3_store).to receive(:update_file_access_control)
      allow(Discourse.store).to receive(:get_path_for_upload).and_return(final_path)

      result = adapter.handle_completion(job_id, new_sha1)

      expect(result).to be true
      # Verify s3_helper operations
      expect(s3_helper).to have_received(:object).with(temp_path)
      expect(source_s3_object).to have_received(:exists?)
      expect(source_s3_object).to have_received(:size)
      expect(s3_helper).to have_received(:copy) do |source, dest, options: {}|
        expect(source).to eq(temp_path)
        expect(dest).to include(final_path)
      end
      expect(s3_helper).to have_received(:object).at_least(:once)
      expect(destination_s3_object).to have_received(:exists?)
      expect(s3_helper).to have_received(:remove).with(temp_path, false)
      expect(s3_store).to have_received(:update_file_access_control).at_least(:once)
      # The hash passed to create_for uses symbol keys (from **options)
      expect(OptimizedVideo).to have_received(
        :create_for,
      ) do |upload_arg, filename, user_id, options|
        expect(upload_arg).to eq(upload)
        expect(filename).to eq("video_converted.mp4")
        expect(user_id).to eq(upload.user_id)
        expect(options[:extension]).to eq("mp4")
        expect(options[:filesize]).to eq(1024)
        expect(options[:sha1]).to eq(new_sha1)
        # URL will include the destination path (with or without multisite prefix)
        expect(options[:url]).to match(
          %r{//#{s3_bucket}\.s3\.dualstack\.#{s3_region}\.amazonaws\.com.*#{final_path}},
        )
        expect(options[:etag]).to eq("etag123")
        expect(options[:adapter]).to eq("aws_mediaconvert")
      end
      expect(post).to have_received(:rebake!)
      expect(Rails.logger).to have_received(:info).with(/Rebaking post #{post.id}/)
    end

    context "when S3 object doesn't exist" do
      before do
        allow(s3_helper).to receive(:object).with(temp_path).and_return(source_s3_object)
        allow(source_s3_object).to receive(:exists?).and_return(false)
      end

      it "returns false" do
        expect(adapter.handle_completion(job_id, new_sha1)).to be false
      end
    end

    context "when source object doesn't exist for copy" do
      before do
        allow(s3_object).to receive(:exists?).and_return(true)
        allow(source_s3_object).to receive(:exists?).and_return(false)
        allow(Discourse.store).to receive(:get_path_for_upload).and_return(final_path)
      end

      it "returns false and logs error" do
        result = adapter.handle_completion(job_id, new_sha1)
        expect(Rails.logger).to have_received(:error).with(
          /MediaConvert temp file not found at #{temp_path}/,
        )
        expect(result).to be false
      end
    end

    context "when copy fails" do
      let(:error) { StandardError.new("Copy failed") }

      before do
        allow(s3_helper).to receive(:object).with(temp_path).and_return(source_s3_object)
        allow(source_s3_object).to receive(:exists?).and_return(true)
        allow(source_s3_object).to receive(:size).and_return(1024)
        allow(s3_helper).to receive(:copy) do |source, dest, options: {}|
          raise error if source == temp_path && dest.include?(final_path)
        end
        allow(Discourse.store).to receive(:get_path_for_upload).and_return(final_path)
      end

      it "returns false and logs error" do
        adapter.handle_completion(job_id, new_sha1)
        expect(Discourse).to have_received(:warn_exception) do |exception, options|
          expect(exception).to eq(error)
          expect(options[:message]).to eq("Error in video processing completion")
          expect(options[:env][:upload_id]).to eq(upload.id)
          expect(options[:env][:job_id]).to eq(job_id)
          expect(options[:env][:temp_path]).to eq(temp_path)
          expect(options[:env][:error_class]).to eq("StandardError")
          expect(options[:env][:error_message]).to eq("Copy failed")
        end
        expect(adapter.handle_completion(job_id, new_sha1)).to be false
      end
    end

    context "when delete fails" do
      let(:delete_error) { StandardError.new("Delete failed") }

      before do
        allow(s3_helper).to receive(:object) do |path|
          if path == temp_path
            source_s3_object
          elsif path.include?(final_path)
            destination_s3_object
          else
            source_s3_object
          end
        end
        allow(source_s3_object).to receive(:exists?).and_return(true)
        allow(source_s3_object).to receive(:size).and_return(1024)
        allow(s3_helper).to receive(:copy) do |source, dest, options: {}|
          [dest, "etag123"] if source == temp_path && dest.include?(final_path)
        end
        allow(destination_s3_object).to receive(:exists?).and_return(true)
        allow(s3_helper).to receive(:remove).with(temp_path, false).and_raise(delete_error)
        allow(OptimizedVideo).to receive(:create_for).and_return(true)
        allow(s3_store).to receive(:update_file_access_control)
        allow(Discourse.store).to receive(:get_path_for_upload).and_return(final_path)
      end

      it "logs warning but continues" do
        result = adapter.handle_completion(job_id, new_sha1)
        expect(Rails.logger).to have_received(:warn).with(
          /Failed to delete temporary MediaConvert file/,
        )
        expect(result).to be true
      end
    end

    context "when optimized video creation fails" do
      before do
        allow(s3_helper).to receive(:object) do |path|
          if path == temp_path
            source_s3_object
          elsif path.include?(final_path)
            destination_s3_object
          else
            source_s3_object
          end
        end
        allow(source_s3_object).to receive(:exists?).and_return(true)
        allow(source_s3_object).to receive(:size).and_return(1024)
        allow(s3_helper).to receive(:copy) do |source, dest, options: {}|
          [dest, "etag123"] if source == temp_path && dest.include?(final_path)
        end
        allow(destination_s3_object).to receive(:exists?).and_return(true)
        allow(s3_helper).to receive(:remove).with(temp_path, false)
        allow(OptimizedVideo).to receive(:create_for).and_return(false)
        allow(s3_store).to receive(:update_file_access_control)
        allow(Discourse.store).to receive(:get_path_for_upload).and_return(final_path)
      end

      it "returns false and logs error" do
        adapter.handle_completion(job_id, new_sha1)
        expect(Rails.logger).to have_received(:error).with(/Failed to create OptimizedVideo record/)
        expect(adapter.handle_completion(job_id, new_sha1)).to be false
      end
    end

    context "when an error occurs" do
      let(:error) { StandardError.new("Test error") }

      before do
        allow(s3_helper).to receive(:object) do |path|
          if path == temp_path
            source_s3_object
          elsif path.include?(final_path)
            destination_s3_object
          else
            source_s3_object
          end
        end
        allow(source_s3_object).to receive(:exists?).and_return(true)
        allow(source_s3_object).to receive(:size).and_return(1024)
        allow(s3_helper).to receive(:copy) do |source, dest, options: {}|
          [dest, "etag123"] if source == temp_path && dest.include?(final_path)
        end
        allow(destination_s3_object).to receive(:exists?).and_return(true)
        allow(s3_helper).to receive(:remove).with(temp_path, false)
        allow(OptimizedVideo).to receive(:create_for).and_raise(error)
        allow(s3_store).to receive(:update_file_access_control)
        allow(Discourse.store).to receive(:get_path_for_upload).and_return(final_path)
      end

      it "returns false and logs error" do
        adapter.handle_completion(job_id, new_sha1)
        expect(Discourse).to have_received(:warn_exception) do |exception, options|
          expect(exception).to eq(error)
          expect(options[:message]).to eq("Error in video processing completion")
          expect(options[:env][:upload_id]).to eq(upload.id)
          expect(options[:env][:job_id]).to eq(job_id)
          expect(options[:env][:temp_path]).to eq(temp_path)
          expect(options[:env][:error_class]).to eq("StandardError")
          expect(options[:env][:error_message]).to eq("Test error")
        end
        expect(adapter.handle_completion(job_id, new_sha1)).to be false
      end
    end
  end
end
