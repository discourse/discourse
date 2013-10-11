require 'spec_helper'

describe Oneboxer::TwitterOnebox do
  subject { described_class.new(nil, nil) }

  let(:data) { %({ "text":"#{text}", "created_at":"#{created_at}" }) }

  let(:text) { '' }
  let(:created_at) { '2013-06-13T22:37:05Z' }

  describe '#parse' do
    it 'formats the timestamp' do
      expect(subject.parse(data)['created_at']).to eq '10:37PM - 13 Jun 13'
    end

    context 'when text contains a url' do
      let(:text) { 'Twitter http://twitter.com' }

      it 'wraps eack url in a link' do
        expect(subject.parse(data)['text']).to eq([
          "Twitter ",
          '<a href="http://twitter.com" target="_blank">',
            "http://twitter.com",
          "</a>"
        ].join)
      end
    end

    context 'when the text contains a twitter handle' do
      let(:text) { 'I like @chrishunt' }

      it 'wraps each handle in a link' do
        expect(subject.parse(data)['text']).to eq([
          "I like ",
          "<a href='https://twitter.com/chrishunt' target='_blank'>",
            "@chrishunt",
          "</a>"
        ].join)
      end
    end

    context 'when the text contains a hashtag' do
      let(:text) { 'No secrets. #NSA' }

      it 'wraps each hashtag in a link' do
        expect(subject.parse(data)['text']).to eq([
          "No secrets. ",
          "<a href='https://twitter.com/search?q=%23NSA' target='_blank'>",
            "#NSA",
          "</a>"
        ].join)
      end
    end
  end
end

