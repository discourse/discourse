require 'feed_element_installer'
require 'rails_helper'

describe FeedElementInstaller do
  describe '#install_rss_element' do
    let(:raw_feed) { file_from_fixtures('feed.rss', 'feed').read }

    it 'creates parsing for a non-standard, namespaced element' do
      FeedElementInstaller.install('discourse:username', raw_feed)
      feed = RSS::Parser.parse(raw_feed)

      expect(feed.items.first.discourse_username).to eq('xrav3nz')
    end

    it 'does not create parsing for a non-standard, non-namespaced element' do
      FeedElementInstaller.install('username', raw_feed)
      feed = RSS::Parser.parse(raw_feed)

      expect { feed.items.first.username }.to raise_error(NoMethodError)
    end
  end

  describe '#install_atom_element' do
    let(:raw_feed) { file_from_fixtures('feed.atom', 'feed').read }

    it 'creates parsing for a non-standard, namespaced element' do
      FeedElementInstaller.install('discourse:username', raw_feed)
      feed = RSS::Parser.parse(raw_feed)

      expect(feed.items.first.discourse_username).to eq('xrav3nz')
    end

    it 'does not create parsing for a non-standard, non-namespaced element' do
      FeedElementInstaller.install('username', raw_feed)
      feed = RSS::Parser.parse(raw_feed)

      expect { feed.items.first.username }.to raise_error(NoMethodError)
    end
  end
end
