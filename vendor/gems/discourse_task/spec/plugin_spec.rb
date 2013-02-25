require 'spec_helper'
require 'discourse_task/plugin'

describe DiscourseTask::Plugin do

  let(:registry) { stub_everything }
  let(:plugin) { DiscourseTask::Plugin.new(registry) }

  context '.setup' do

    it 'registers its js' do
      plugin.expects(:register_js).with('discourse_task')
      plugin.setup
    end

    it 'registers its css' do
      plugin.expects(:register_css).with('discourse_task')
      plugin.setup
    end

    it 'registers a task archetype' do
      plugin.expects(:register_archetype).with('task')
      plugin.setup
    end

  end

end
