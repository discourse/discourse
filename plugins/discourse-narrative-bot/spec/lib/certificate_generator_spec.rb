require 'rails_helper'

RSpec.describe DiscourseNarrativeBot::CertificateGenerator do
  let(:user) { Fabricate(:user) }

  describe 'when an invalid date is given' do
    it 'should default to the current date' do
      expect { described_class.new(user, "2017-00-10") }.to_not raise_error
    end
  end
end
