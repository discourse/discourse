require 'spec_helper'
require_dependency 'jobs/base'

describe Jobs::Base do

  it 'delegates the process call to execute' do
    Jobs::Base.any_instance.expects(:execute).with('hello' => 'world')
    Jobs::Base.new.perform('hello' => 'world', 'sync_exec' => true)
  end

  it 'converts to an indifferent access hash' do
    Jobs::Base.any_instance.expects(:execute).with(instance_of(HashWithIndifferentAccess))
    Jobs::Base.new.perform('hello' => 'world', 'sync_exec' => true)
  end

end

