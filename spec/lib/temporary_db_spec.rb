# frozen_string_literal: true
RSpec.describe TemporaryDb do
  describe "#pg_port" do
    it "reserves different ports across processes" do
      port_readers = []
      release_writers = []
      process_ids = []

      2.times do
        port_reader, port_writer = IO.pipe
        release_reader, release_writer = IO.pipe

        process_ids << fork do
          port_reader.close
          release_writer.close

          temporary_db = described_class.new
          port_writer.puts(temporary_db.pg_port)
          port_writer.close
          release_reader.read(1)
          release_reader.close
        end

        port_writer.close
        release_reader.close
        port_readers << port_reader
        release_writers << release_writer
      end

      ports = port_readers.map { |port_reader| Integer(port_reader.gets) }

      expect(ports.uniq.length).to eq(2)
    ensure
      port_readers&.each(&:close)
      release_writers&.each do |release_writer|
        release_writer.write(".")
        release_writer.close
      rescue Errno::EPIPE
        nil
      end
      process_ids&.each { |process_id| Process.wait(process_id) }
    end
  end
end
