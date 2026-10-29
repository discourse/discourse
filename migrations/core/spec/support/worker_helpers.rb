# frozen_string_literal: true

require "timeout"

module MigrationsWorkerHelpers
  def in_migration_worker(&block)
    reader, writer = IO.pipe
    pid =
      Migrations::ForkManager.fork do
        reader.close
        begin
          Marshal.dump(block.call, writer)
          writer.close
          Process.exit!(0)
        rescue Exception => error
          warn "#{error.class}: #{error.message}"
          Process.exit!(1)
        end
      end
    writer.close
    result = reader.read
    _, status = Process.waitpid2(pid)
    expect(status).to be_success
    Marshal.load(result) # rubocop:disable Security/MarshalLoad -- Only this test's child writes the pipe.
  ensure
    reader&.close
    writer&.close unless writer&.closed?
  end

  def wait_until_stopped(thread)
    Timeout.timeout(5) { Thread.pass until thread.stop? }
  end
end

RSpec.configure { |config| config.include MigrationsWorkerHelpers }
