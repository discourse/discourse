require 'feed_element_installer'
require 'rails_helper'

describe FeedElementInstaller do
  describe '#install_rss_element' do
    let(:rss_feed_file) { file_from_fixtures('feed.rss', 'feed') }

    it 'creates parsing for a non-standard, non-namespaced element' do
      FeedElementInstaller.install_rss_element('username')

      feed = RSS::Parser.parse(rss_feed_file, false)

      expect(feed.items.first.username).to eq('xrav3nz')
    end
  end

  describe '#install_atom_element' do
    let(:atom_feed_file) { file_from_fixtures('feed.atom', 'feed') }

    it 'creates parsing for a non-standard, non-namespaced element' do
      FeedElementInstaller.install_atom_element('username')

      feed = RSS::Parser.parse(atom_feed_file, false)

      expect(feed.items.first.username).to eq('xrav3nz')
    end
  end
end
