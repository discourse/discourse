require 'rails_helper'

describe UsernameValidator do
  context "#valid_format?" do
    it 'returns true when username is both valid and available' do
      expect(UsernameValidator.new('Available').valid_format?).to eq true
    end

    it 'returns true when the username is valid but not available' do
      expect(UsernameValidator.new(Fabricate(:user).username).valid_format?).to eq true
    end

    it 'returns false when the username is not valid' do
      expect(UsernameValidator.new('not valid.name').valid_format?).to eq false
    end
  end
end
