require 'rails_helper'
require_relative '../lib/log_analyzer'

describe LogAnalyzer::LineParser do
  describe '.parse' do
    let(:line) { '[22/Sep/2016:07:32:00 +0000] 172.0.0.1 "GET /about.json?api_username=system&api_key=1234567 HTTP/1.1" "Some usename" "about/index" 200 1641 "-" 0.014 0.014 "system"' }

    it "should filter out the api_key" do
      result = described_class.parse(line)
      expect(result.url).to eq('GET /about.json?api_username=system&api_key=[FILTERED] HTTP/1.1')
    end
  end
end
