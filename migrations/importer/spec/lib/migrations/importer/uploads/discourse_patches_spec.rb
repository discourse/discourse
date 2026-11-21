# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::DiscoursePatches do
  # `apply!` patches the real Rails classes for the whole process, so these
  # examples prepend the two modules to small host classes instead. They cover
  # the DistributedMutex bypass only; the ActiveRecord patches need a booted
  # Rails and are not covered here.

  # Takes its lock unless the bypass is on, like DistributedMutex.
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

  # Uses the mutex inside `create_for`, like UploadCreator.
  let(:creator_class) do
    Class.new do
      prepend Migrations::Importer::Uploads::DiscoursePatches::CreatorMutexScope

      def initialize(mutex)
        @mutex = mutex
      end

      def create_for(_user_id)
        @mutex.synchronize("upload_-1_file.png") { yield if block_given? }
        :created
      end
    end
  end

  it "skips the mutex lock inside create_for and takes it again afterwards" do
    creator = creator_class.new(mutex_class)

    expect(creator.create_for(-1)).to eq(:created)
    expect(mutex_class.locked).to be_nil

    expect(mutex_class.synchronize("upload_-1_file.png") { :block_ran }).to eq(:block_ran)
    expect(mutex_class.locked).to be(true)
  end

  it "keeps the bypass on for the rest of an outer create_for after a nested one" do
    creator = creator_class.new(mutex_class)

    creator.create_for(1) do
      creator.create_for(2)
      expect(described_class.bypassing_upload_mutex?).to be(true)
    end

    expect(described_class.bypassing_upload_mutex?).to be_falsey
  end
end
