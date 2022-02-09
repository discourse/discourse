# frozen_string_literal: true

require 'rails_helper'

describe TwitterApi do
  context '.link_handles_in' do
    it 'correctly replaces handles' do
      expect(TwitterApi.send(:link_handles_in, "@foo @foobar")).to match_html <<~HTML
        <a href='https://twitter.com/foo' target='_blank'>@foo</a> <a href='https://twitter.com/foobar' target='_blank'>@foobar</a>
      HTML
    end
  end

  context '.link_hashtags_in' do
    it 'correctly replaces hashtags' do
      expect(TwitterApi.send(:link_hashtags_in, "#foo #foobar")).to match_html <<~HTML
        <a href='https://twitter.com/search?q=%23foo' target='_blank'>#foo</a> <a href='https://twitter.com/search?q=%23foobar' target='_blank'>#foobar</a>
      HTML
    end
  end
end
