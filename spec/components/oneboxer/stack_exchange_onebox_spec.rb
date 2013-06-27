require 'spec_helper'

describe Oneboxer::StackExchangeOnebox do
  describe '#translate_url' do
    let(:question) { '15622543' }
    let(:api_url) {
      "http://api.stackexchange.com/2.1/questions/#{question}?site=#{site}"
    }

    context 'when the question is from Stack Overflow' do
      let(:site) { 'stackoverflow' }

      it 'returns the correct api url for an expanded url' do
        onebox = described_class.new([
          "http://#{site}.com/",
          "questions/#{question}/discourse-ruby-2-0-rails-4"
        ].join)

        expect(onebox.translate_url).to eq api_url
      end

      it 'returns the correct api url for a share url' do
        onebox = described_class.new("http://#{site}.com/q/#{question}")

        expect(onebox.translate_url).to eq api_url
      end
    end

    context 'when the question is from Super User' do
      let(:site) { 'superuser' }

      it 'returns the correct api url' do
        onebox = described_class.new("http://#{site}.com/q/#{question}")

        expect(onebox.translate_url).to eq api_url
      end
    end

    context 'when the question is from Meta Stack Overflow' do
      let(:site) { 'meta.stackoverflow' }

      it 'returns the correct api url' do
        onebox = described_class.new("http://meta.stackoverflow.com/q/#{question}")

        expect(onebox.translate_url).to eq api_url
      end
    end

    context 'when the question is from a Meta Stack Exchange subdomain' do
      let(:site) { 'meta.gamedev' }

      it 'returns the correct api url' do
        onebox = described_class.new("http://meta.gamedev.stackexchange.com/q/#{question}")

        expect(onebox.translate_url).to eq api_url
      end

    end

    context 'when the question is from a Stack Exchange subdomain' do
      let(:site) { 'gamedev' }

      it 'returns the correct api url' do
        onebox = described_class.new([
          "http://#{site}.stackexchange.com/",
          "questions/#{question}/how-to-prevent-the-too-awesome-to-use-syndrome"
        ].join)

        expect(onebox.translate_url).to eq api_url
      end
    end
  end
end
