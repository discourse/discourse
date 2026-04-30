# frozen_string_literal: true

require "discourse/seccomp"

RSpec.describe Discourse::Seccomp do
  describe ".deny_network!" do
    it "denies socket creation while leaving regular filesystem access available" do
      skip "seccomp is not supported" if !described_class.supported?

      stdout_read, stdout_write = IO.pipe

      pid =
        fork do
          stdout_read.close
          STDOUT.reopen(stdout_write)
          stdout_write.close

          described_class.deny_network!

          begin
            UDPSocket.new
            puts "udp_allowed"
          rescue SystemCallError => e
            puts "udp_denied=#{e.class}"
          end

          File.read("/etc/hosts")
          puts "file_read_allowed"
          exit! 0
        end

      stdout_write.close
      output = stdout_read.read
      _, status = Process.wait2(pid)

      expect(status.exitstatus).to eq(0)
      expect(output).to include("udp_denied=Errno::EPERM")
      expect(output).to include("file_read_allowed")
    ensure
      [stdout_read, stdout_write].each do |io|
        io&.close unless io.closed?
      rescue IOError
      end
    end
  end
end
