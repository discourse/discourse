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

  context ".perform_validation" do
    subject { described_class.perform_validation(user, 'name') }

    context "with a valid username" do
      let(:user) { Fabricate(:user, name: 'valid_name') }
      it 'returns nil' do
        expect(subject).to eq nil
      end

      it 'does not add errors to the passed in user' do
        expect(user.errors.messages).to eq({:email=>[]})
      end
    end

    context "with an invalid username" do
      let(:user) { Fabricate(:user, name: 'invalid name') }
      it 'adds errors to the passed in user' do
        expect(subject).to eq ["must only include numbers, letters and underscores"]
        expect(user.errors.messages).to eq({:email=>[], :name=>["must only include numbers, letters and underscores"]})
      end
    end
  end
end
