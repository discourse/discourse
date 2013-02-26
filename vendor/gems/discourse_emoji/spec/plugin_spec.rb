require 'spec_helper'
require 'discourse_emoji/plugin'
require 'ostruct'

describe DiscourseEmoji::Plugin do

  let(:registry) { stub_everything }
  let(:plugin) { DiscourseEmoji::Plugin.new(registry) }

  context '.setup' do

    it 'registers its js' do
      plugin.expects(:register_js).with('discourse_emoji', any_parameters)
      plugin.setup
    end

    it 'registers its css' do
      plugin.expects(:register_css).with('discourse_emoji')
      plugin.setup
    end

  end

end
