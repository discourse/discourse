require 'spec_helper'
require 'discourse_poll/plugin'
require 'ostruct'

describe DiscoursePoll::Plugin do

  let(:registry) { stub_everything }
  let(:plugin) { DiscoursePoll::Plugin.new(registry) }

  context '.setup' do

    it 'registers its js' do
      plugin.expects(:register_js)
      plugin.setup
    end

    it 'registers its css' do
      plugin.expects(:register_css)
      plugin.setup
    end

    it 'registers a poll archetype' do
      plugin.expects(:register_archetype).with('poll', DiscoursePoll::Plugin::POLL_OPTIONS)
      plugin.setup
    end

    it 'registers a handler on post_create' do
      plugin.expects(:listen_for).with(:before_create_post)
      plugin.setup
    end
  end


  context ".before_create_post" do

    context 'without a poll' do
      let(:post) { OpenStruct.new(archetype: 'something-else', post_number: 1000) }

      it "doesn't set the sort order" do
        plugin.before_create_post(post)
        post.sort_order.should_not == DiscoursePoll::Plugin::MAX_SORT_ORDER
      end

    end

    context 'with a poll' do
      let(:post) { OpenStruct.new(archetype: 'poll') }

      it 'sets the sort order to 1 when the post_number is 1' do
        post.post_number = 1
        plugin.before_create_post(post)
        post.sort_order.should == 1
      end

      it 'sets the sort order to MAX_SORT_ORDER when the post_number is not 1' do
        post.post_number = 1000
        plugin.before_create_post(post)
        post.sort_order.should == DiscoursePoll::Plugin::MAX_SORT_ORDER
      end

    end

  end


end
