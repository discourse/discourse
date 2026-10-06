# frozen_string_literal: true

require "aws-sdk-s3"

RSpec.describe BackupRestore::MultipartWriter do
  let(:client) { Aws::S3::Client.new(stub_responses: true, region: "us-east-1") }
  let(:upload) do
    Aws::S3::MultipartUpload.new(
      bucket_name: "backups",
      object_key: "default/backup.tar",
      id: "upload-id",
      client: client,
    )
  end

  around { |example| stub_const(described_class, "PART_SIZE", 8) { example.run } }
  before { GlobalSetting.stubs(:backup_s3_upload_concurrency).returns(2) }

  it "keeps producing and uploading parts while an earlier part is blocked" do
    release_first = Queue.new
    completed = Queue.new
    paths = Queue.new
    client.stub_responses(
      :upload_part,
      ->(context) do
        number = context.params[:part_number]
        paths << context.params[:body].path
        release_first.pop if number == 1
        completed << number
        { etag: "etag-#{number}" }
      end,
    )
    logs = []

    described_class.open(upload, logger: logs.method(:<<)) do |writer|
      begin
        Timeout.timeout(5) do
          writer.write("a" * 24)
          expect([completed.pop, completed.pop]).to eq([2, 3])
        end
        expect(
          client.api_requests.none? { |r| r[:operation_name] == :complete_multipart_upload },
        ).to eq(true)
      ensure
        release_first << true
      end
      writer.finish
    end

    parts = client.api_requests.last[:params][:multipart_upload][:parts]
    expect(parts).to eq((1..3).map { |number| { part_number: number, etag: "etag-#{number}" } })
    expect(3.times.map { paths.pop }.none? { |path| File.exist?(path) }).to eq(true)
    expect(logs.last).to include("3 parts", "average part upload", "waiting for a free buffer")
  end

  it "bounds buffers and joins active workers when a blocked producer is cancelled" do
    arrivals = Queue.new
    release = Queue.new
    filled = Queue.new
    closing = Queue.new
    producer = nil
    workers = []
    directory = nil
    client.stub_responses(
      :upload_part,
      ->(context) do
        arrivals << [Thread.current, File.dirname(context.params[:body].path)]
        release.pop
        { etag: "etag" }
      end,
    )
    resource = upload

    begin
      Timeout.timeout(5) do
        producer =
          Thread.new do
            Thread.current.report_on_exception = false
            described_class.open(resource) do |writer|
              writer
                .instance_variable_get(:@pending)
                .define_singleton_method(:close) do
                  result = super()
                  closing << true
                  result
                end
              writer.write("a" * 24)
              filled << true
              writer.write("b" * 8)
              writer.finish
            end
          end
        workers, directories = 2.times.map { arrivals.pop }.transpose
        directory = directories.first
        filled.pop
        expect(Dir.children(directory).size).to eq(3)
        expect(Dir.glob("#{directory}/*").sum { |path| File.size(path) }).to eq(24)

        producer.raise(SystemExit)
        closing.pop
        expect(producer.alive?).to eq(true)
        2.times { release << true }
        expect { producer.value }.to raise_error(SystemExit)
      end
      expect(workers.none?(&:alive?)).to eq(true)
      expect(Dir.exist?(directory)).to eq(false)
      expect(client.api_requests.count { |r| r[:operation_name] == :upload_part }).to eq(2)
      expect(
        client.api_requests.none? { |r| r[:operation_name] == :complete_multipart_upload },
      ).to eq(true)
    ensure
      5.times { release << true }
      begin
        producer&.join
      rescue SystemExit
      end
    end
  end

  it "wakes a producer waiting for a buffer when an upload fails" do
    GlobalSetting.stubs(:backup_s3_upload_concurrency).returns(1)
    client.stub_responses(:upload_part, "AccessDenied")

    expect do
      Timeout.timeout(5) do
        described_class.open(upload) do |writer|
          writer.write("a" * 80)
          writer.finish
        end
      end
    end.to raise_error(Aws::S3::Errors::AccessDenied)
    expect(
      client.api_requests.none? { |r| r[:operation_name] == :complete_multipart_upload },
    ).to eq(true)
  end
end
