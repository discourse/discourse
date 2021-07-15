# frozen_string_literal: true

require "rails_helper"
require_relative "shared_context_for_backup_restore"

describe BackupRestore::SystemInterface, type: :multisite do
  include_context "shared stuff"

  subject { BackupRestore::SystemInterface.new(logger) }

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

        subject.flush_redis

        expect(Discourse.redis.get("foo")).to be_nil
        expect(Discourse.redis.get("bar")).to be_nil
      end

      test_multisite_connection("default") do
        expect(Discourse.redis.get("foo")).to eq("default-foo")
        expect(Discourse.redis.get("bar")).to eq("default-bar")
      end
    end
  end
end
