# frozen_string_literal: true

require 'rss'
require 'feed_item_accessor'
require 'rails_helper'

describe FeedItemAccessor do
  context 'for ATOM feed' do
    let(:atom_feed) { RSS::Parser.parse(file_from_fixtures('feed.atom', 'feed'), false) }
    let(:atom_feed_item) { atom_feed.items.first }
    let(:item_accessor) { FeedItemAccessor.new(atom_feed_item) }

    describe '#element_content' do
      it { expect(item_accessor.element_content('title')).to eq(atom_feed_item.title.content) }
    end

    describe '#link' do
      it { expect(item_accessor.link).to eq(atom_feed_item.link.href) }
    end
  end

  context 'for RSS feed' do
    let(:rss_feed) { RSS::Parser.parse(file_from_fixtures('feed.rss', 'feed'), false) }
    let(:rss_feed_item) { rss_feed.items.first }
    let(:item_accessor) { FeedItemAccessor.new(rss_feed_item) }

    describe '#element_content' do
      it { expect(item_accessor.element_content('title')).to eq(rss_feed_item.title) }
    end

    describe '#link' do
      it { expect(item_accessor.link).to eq(rss_feed_item.link) }
    end
  end
end
