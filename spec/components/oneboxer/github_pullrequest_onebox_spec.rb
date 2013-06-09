require 'spec_helper'
require 'oneboxer'
require 'oneboxer/github_pullrequest_onebox'

describe Oneboxer::GithubPullrequestOnebox do
  describe '#translate_url' do
    it 'returns the api url for the given pull request' do
      onebox = described_class.new(
        'https://github.com/discourse/discourse/pull/988'
      )
      expect(onebox.translate_url).to eq(
        'https://api.github.com/repos/discourse/discourse/pulls/988'
      )
    end
  end
end

