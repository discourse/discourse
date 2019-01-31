require 'rails_helper'

RSpec.describe Jobs::PostUploadsRecovery do
  describe '#grace_period' do
    it 'should restrict the grace period to the right range' do
      SiteSetting.purge_deleted_uploads_grace_period_days =
        described_class::MIN_PERIOD - 1

      expect(described_class.new.grace_period).to eq(30)

      SiteSetting.purge_deleted_uploads_grace_period_days =
        described_class::MAX_PERIOD + 1

      expect(described_class.new.grace_period).to eq(120)
    end
  end
end
