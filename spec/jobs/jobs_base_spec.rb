require 'spec_helper'
require_dependency 'jobs/base'

describe Jobs::Base do
  class BadJob < Jobs::Base
    attr_accessor :fail_count

    def execute(args)
      @fail_count ||= 0
      @fail_count += 1
      raise StandardError
    end
  end

  it 'handles errors in multisite' do
    RailsMultisite::ConnectionManagement.expects(:all_dbs).returns(['default','default'])
    # just stub so logs are not noisy
    Discourse.expects(:handle_exception).returns(nil)

    bad = BadJob.new 
    expect{bad.perform({})}.to raise_error
    bad.fail_count.should == 2
  end

  it 'delegates the process call to execute' do
    Jobs::Base.any_instance.expects(:execute).with('hello' => 'world')
    Jobs::Base.new.perform('hello' => 'world', 'sync_exec' => true)
  end

  it 'converts to an indifferent access hash' do
    Jobs::Base.any_instance.expects(:execute).with(instance_of(HashWithIndifferentAccess))
    Jobs::Base.new.perform('hello' => 'world', 'sync_exec' => true)
  end

end

