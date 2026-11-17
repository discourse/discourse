# frozen_string_literal: true

RSpec.describe DiscourseVips::WorkerProcess do
  describe ".shared_socket_path" do
    it "returns a stable short address for long Unicode checkout paths" do
      Rails.stubs(:root).returns(Pathname.new("/checkouts/#{"画像" * 100}"))

      path = described_class.shared_socket_path

      expect(path).to start_with("/tmp/discourse-vips/test/")
      expect(path).to end_with("/socket")
      expect(path.bytesize).to be < 104
      expect(described_class.shared_socket_path).to eq(path)
    end

    it "isolates checkouts with the same basename" do
      Rails.stubs(:root).returns(Pathname.new("/checkouts/first/discourse"))
      first_path = described_class.shared_socket_path
      Rails.stubs(:root).returns(Pathname.new("/checkouts/second/discourse"))

      expect(described_class.shared_socket_path).not_to eq(first_path)
    end

    it "isolates environments using the same directory layout" do
      paths =
        %w[development production test].map do |environment|
          Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new(environment))
          path = described_class.shared_socket_path

          expect(path).to start_with("/tmp/discourse-vips/#{environment}/")
          path
        end

      expect(paths.uniq.size).to eq(3)
      expect(paths.map { |path| File.basename(File.dirname(path)) }.uniq.size).to eq(1)
    end
  end

  describe "shared worker lifecycle" do
    it "serves requests from a long Unicode checkout and restarts after cleanup" do
      application_root = Rails.root
      worker = nil
      socket = nil

      Dir.mktmpdir do |directory|
        root = Pathname.new(directory).join("画像" * 35)
        FileUtils.mkdir_p(root)
        FileUtils.ln_s(application_root.join("lib"), root.join("lib"))
        FileUtils.ln_s(application_root.join("script"), root.join("script"))
        Rails.stubs(:root).returns(root)
        socket_path = described_class.shared_socket_path

        2.times do
          worker = described_class.new(socket_path:)

          socket = UNIXSocket.new(socket_path)
          socket.write(MessagePack.pack(command: ["version"], timeout: 5, read: [], write: []))
          socket.close_write
          response = MessagePack.unpack(socket.read)
          socket.close

          expect(response).to include("status" => "ok", "value" => match(/\A\d+\.\d+\.\d+\z/))
          expect(File.stat(File.dirname(socket_path)).mode & 0o777).to eq(0o700)
          expect(File.stat(socket_path).mode & 0o777).to eq(0o600)

          worker.shutdown

          expect(File.exist?(File.dirname(socket_path))).to eq(false)
        end
      end
    ensure
      socket&.close unless socket&.closed?
      worker&.shutdown
    end
  end
end
