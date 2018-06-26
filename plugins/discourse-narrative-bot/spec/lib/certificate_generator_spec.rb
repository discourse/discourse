require 'rails_helper'

RSpec.describe DiscourseNarrativeBot::CertificateGenerator do
  let(:user) { Fabricate(:user) }

  describe 'when an invalid date is given' do
    it 'should default to the current date' do
      expect { described_class.new(user, "2017-00-10") }.to_not raise_error
    end
  end

  describe '#logo_group' do
    describe 'when SiteSetting.logo_small_url is blank' do
      before do
        SiteSetting.logo_small_url = ''
      end

      it 'should not try to fetch a image' do
        expect(described_class.new(user, "2017-02-10").send(:logo_group, 1, 1, 1))
          .to eq(nil)
      end
    end
  end
end
