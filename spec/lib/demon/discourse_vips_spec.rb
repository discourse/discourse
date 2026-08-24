# frozen_string_literal: true

RSpec.describe Demon::DiscourseVips do
  describe "#run" do
    it "does not start the broker when the pid file cannot be written" do
      daemon = described_class.new(0)
      reader, writer = IO.pipe

      Discourse.stubs(:before_fork)
      daemon.stubs(:write_pid_file).raises("cannot write pid file")
      daemon.stubs(:establish_app)
      daemon.stubs(:after_fork) { writer.write("started") }

      expect { daemon.run }.to raise_error("cannot write pid file")
      writer.close
      Process.wait(daemon.pid)

      expect(reader.read).to eq("")
    ensure
      reader&.close
      writer&.close unless writer&.closed?
    end
  end
end
