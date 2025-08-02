# frozen_string_literal: true

require_relative "shared_context_for_backup_restore"

RSpec.describe BackupRestore::SystemInterface do
  subject(:system_interface) { BackupRestore::SystemInterface.new(logger) }

  include_context "with shared backup restore context"

  describe "readonly mode" do
    after { Discourse::READONLY_KEYS.each { |key| Discourse.redis.del(key) } }

    describe "#enable_readonly_mode" do
      it "enables readonly mode" do
        Discourse.expects(:enable_readonly_mode).once
        system_interface.enable_readonly_mode
      end

      it "does not enable readonly mode when it is already in readonly mode" do
        Discourse.enable_readonly_mode
        Discourse.expects(:enable_readonly_mode).never
        system_interface.enable_readonly_mode
      end
    end

    describe "#disable_readonly_mode" do
      it "disables readonly mode" do
        Discourse.expects(:disable_readonly_mode).once
        system_interface.disable_readonly_mode
      end

      it "does not disable readonly mode when readonly mode was explicitly enabled" do
        Discourse.enable_readonly_mode
        Discourse.expects(:disable_readonly_mode).never
        system_interface.disable_readonly_mode
      end
    end
  end

  describe "#mark_restore_as_running" do
    it "calls mark_restore_as_running" do
      BackupRestore.expects(:mark_as_running!).once
      system_interface.mark_restore_as_running
    end
  end

  describe "#mark_restore_as_not_running" do
    it "calls mark_restore_as_not_running" do
      BackupRestore.expects(:mark_as_not_running!).once
      system_interface.mark_restore_as_not_running
    end
  end

  describe "#listen_for_shutdown_signal" do
    before { BackupRestore.mark_as_running! }

    after do
      BackupRestore.clear_shutdown_signal!
      BackupRestore.mark_as_not_running!
    end

    it "exits the process when shutdown signal is set" do
      expect do
        thread = system_interface.listen_for_shutdown_signal
        BackupRestore.set_shutdown_signal!
        thread.join
      end.to raise_error(SystemExit)
    end

    it "clears an existing shutdown signal before it starts to listen" do
      BackupRestore.set_shutdown_signal!
      expect(BackupRestore.should_shutdown?).to eq(true)

      thread = system_interface.listen_for_shutdown_signal
      expect(BackupRestore.should_shutdown?).to eq(false)
      Thread.kill(thread)
    end
  end

  describe "#pause_sidekiq" do
    after { Sidekiq.unpause! }

    it "calls pause!" do
      expect(Sidekiq.paused?).to eq(false)
      system_interface.pause_sidekiq("my reason")
      expect(Sidekiq.paused?).to eq(true)
      expect(Discourse.redis.get(SidekiqPauser::PAUSED_KEY)).to eq("my reason")
    end
  end

  describe "#unpause_sidekiq" do
    it "calls unpause!" do
      Sidekiq.pause!
      expect(Sidekiq.paused?).to eq(true)

      system_interface.unpause_sidekiq
      expect(Sidekiq.paused?).to eq(false)
    end
  end

  describe "#wait_for_sidekiq" do
    it "waits 6 seconds even when there are no running Sidekiq jobs" do
      system_interface.expects(:sleep).with(6).once
      system_interface.wait_for_sidekiq
    end

    context "with Sidekiq workers" do
      after { Sidekiq.redis(&:flushdb) }

      def create_workers(site_id: nil, all_sites: false)
        payload =
          Sidekiq::Testing.fake! do
            data = { post_id: 1 }

            if all_sites
              data[:all_sites] = true
            else
              data[:current_site_id] = site_id || RailsMultisite::ConnectionManagement.current_db
            end

            Jobs.enqueue(:process_post, data)
            Jobs::ProcessPost.jobs.last
          end

        Sidekiq.redis do |conn|
          hostname = "localhost"
          pid = 7890
          key = "#{hostname}:#{pid}"
          process = { pid: pid, hostname: hostname }

          conn.sadd("processes", key)
          conn.hset(key, "info", Sidekiq.dump_json(process))

          data =
            Sidekiq.dump_json(
              queue: "default",
              run_at: Time.now.to_i,
              payload: Sidekiq.dump_json(payload),
            )
          conn.hset("#{key}:work", "444", data)
        end
      end

      it "waits up to 60 seconds for jobs running for the current site to finish" do
        system_interface.expects(:sleep).with(6).times(10)
        create_workers
        expect { system_interface.wait_for_sidekiq }.to raise_error(
          BackupRestore::RunningSidekiqJobsError,
        )
      end

      it "waits up to 60 seconds for jobs running on all sites to finish" do
        system_interface.expects(:sleep).with(6).times(10)
        create_workers(all_sites: true)
        expect { system_interface.wait_for_sidekiq }.to raise_error(
          BackupRestore::RunningSidekiqJobsError,
        )
      end

      it "ignores jobs of other sites" do
        system_interface.expects(:sleep).with(6).once
        create_workers(site_id: "another_site")

        system_interface.wait_for_sidekiq
      end
    end
  end

  describe "#flush_redis" do
    context "with Sidekiq" do
      after { Sidekiq.unpause! }

      it "doesn't unpause Sidekiq" do
        Sidekiq.pause!
        system_interface.flush_redis

        expect(Sidekiq.paused?).to eq(true)
      end
    end
  end
end
