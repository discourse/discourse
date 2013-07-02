require 'spec_helper'
require 'discourse_mathjax/plugin'
require 'ostruct'

describe DiscourseMathjax::Plugin do

  let(:registry) { stub_everything }
  let(:plugin) { DiscourseMathjax::Plugin.new(registry) }

  context '.setup' do

    it 'registers its js' do
      plugin.expects(:register_js).with('discourse_mathjax', any_parameters)
      plugin.setup
    end

  end

end
