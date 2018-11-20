require 'rails_helper'

RSpec.describe UserSecondFactor do
  describe '.methods' do
    it 'should retain the right order' do
      expect(described_class.methods[:totp]).to eq(1)
      expect(described_class.methods[:backup_codes]).to eq(2)
    end
  end
end
