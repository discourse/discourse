# frozen_string_literal: true

require_relative "shared_context_for_backup_restore"

RSpec.describe BackupRestore::SystemInterface, type: :multisite do
  subject(:system_interface) { BackupRestore::SystemInterface.new(logger) }

  include_context "with shared backup restore context"

  describe "#flush_redis" do
    it "removes only keys from the current site in a multisite" do
      test_multisite_connection("default") do
        Discourse.redis.set("foo", "default-foo")
        Discourse.redis.set("bar", "default-bar")

        expect(Discourse.redis.get("foo")).to eq("default-foo")
        expect(Discourse.redis.get("bar")).to eq("default-bar")
      end

      test_multisite_connection("second") do
        Discourse.redis.set("foo", "second-foo")
        Discourse.redis.set("bar", "second-bar")

        expect(Discourse.redis.get("foo")).to eq("second-foo")
        expect(Discourse.redis.get("bar")).to eq("second-bar")

        system_interface.flush_redis

        expect(Discourse.redis.get("foo")).to be_nil
        expect(Discourse.redis.get("bar")).to be_nil
      end

      test_multisite_connection("default") do
        expect(Discourse.redis.get("foo")).to eq("default-foo")
        expect(Discourse.redis.get("bar")).to eq("default-bar")
      end
    end
  end

  describe "#listen_for_shutdown_signal" do
    it "uses the correct Redis namespace" do
      test_multisite_connection("second") do
        BackupRestore.mark_as_running!

        expect do
          thread = system_interface.listen_for_shutdown_signal
          BackupRestore.set_shutdown_signal!
          thread.join
        end.to raise_error(SystemExit)

        BackupRestore.clear_shutdown_signal!
        BackupRestore.mark_as_not_running!
      end
    end
  end
end
