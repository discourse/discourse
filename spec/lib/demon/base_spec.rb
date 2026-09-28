# frozen_string_literal: true

require "demon/base"

RSpec.describe Demon::Base do
  let(:demon_class) do
    Class.new(described_class) do
      def self.prefix
        "test_demon"
      end
    end
  end

  describe "#run" do
    after { FileUtils.rm_f(Rails.root.join("tmp/pids/test_demon_0.pid")) }

    it "prepares the process for forking by default" do
      demon = demon_class.new(0)
      demon.stubs(:fork).returns(1)
      Discourse.expects(:before_fork).once

      demon.run
    end

    it "does not prepare the process for forking when prepare_fork is false" do
      demon = demon_class.new(0, prepare_fork: false)
      demon.stubs(:fork).returns(1)
      Discourse.expects(:before_fork).never

      demon.run
    end
  end
end
