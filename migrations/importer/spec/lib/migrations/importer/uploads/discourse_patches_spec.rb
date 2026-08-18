# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::DiscoursePatches do
  # The connection/AR-model patches (synchronous_commit, the memoized uploader
  # user, the user_uploads upsert) need a booted Rails and are exercised by the
  # benchmark harness. What is testable without Rails is the DistributedMutex
  # bypass: a thread-local flag set around `create_for` that tells the mutex to
  # yield straight through.

  after { Thread.current[described_class::MUTEX_BYPASS_KEY] = nil }

  # A stand-in for UploadCreator: prepending the scope module should flip the
  # flag on for the duration of the call and restore it afterwards.
  let(:creator_class) do
    Class.new do
      prepend Migrations::Importer::Uploads::DiscoursePatches::CreatorMutexScope

      attr_reader :flag_during_call

      def create_for(_user_id)
        @flag_during_call = Migrations::Importer::Uploads::DiscoursePatches.bypassing_upload_mutex?
        yield if block_given?
        :created
      end
    end
  end

  # A stand-in for DistributedMutex: prepending the bypass on its singleton
  # yields directly while the flag is set, and defers to the original otherwise.
  let(:mutex_class) do
    Class.new do
      class << self
        prepend Migrations::Importer::Uploads::DiscoursePatches::MutexBypass

        attr_accessor :locked

        def synchronize(_key, **)
          @locked = true
          yield
        end
      end
    end
  end

  describe ".bypassing_upload_mutex?" do
    it "is falsey outside a create_for call" do
      expect(described_class.bypassing_upload_mutex?).to be_falsey
    end
  end

  describe "CreatorMutexScope" do
    it "sets the flag while create_for runs and clears it after" do
      creator = creator_class.new

      expect(creator.create_for(1)).to eq(:created)
      expect(creator.flag_during_call).to be(true)
      expect(described_class.bypassing_upload_mutex?).to be_falsey
    end

    it "restores the previous flag value when calls nest" do
      creator = creator_class.new

      creator.create_for(1) do
        expect(described_class.bypassing_upload_mutex?).to be(true)
        creator.create_for(2)
        # the nested call must not have reset the outer flag to nil
        expect(described_class.bypassing_upload_mutex?).to be(true)
      end

      expect(described_class.bypassing_upload_mutex?).to be_falsey
    end
  end

  describe "MutexBypass" do
    it "yields directly and skips the lock while bypassing" do
      Thread.current[described_class::MUTEX_BYPASS_KEY] = true

      result = mutex_class.synchronize("upload_-1_file.png") { :block_ran }

      expect(result).to eq(:block_ran)
      expect(mutex_class.locked).to be_nil
    end

    it "takes the real lock when not bypassing" do
      result = mutex_class.synchronize("upload_-1_file.png") { :block_ran }

      expect(result).to eq(:block_ran)
      expect(mutex_class.locked).to be(true)
    end

    it "bypasses the lock inside a create_for call" do
      creator =
        Class
          .new do
            prepend Migrations::Importer::Uploads::DiscoursePatches::CreatorMutexScope

            def initialize(mutex)
              @mutex = mutex
            end

            def create_for(_user_id)
              @mutex.synchronize("key") { :ok }
            end
          end
          .new(mutex_class)

      expect(creator.create_for(-1)).to eq(:ok)
      expect(mutex_class.locked).to be_nil
    end
  end
end
