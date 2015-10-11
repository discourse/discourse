require 'rails_helper'

describe UsernameChanger do

  describe '#change' do
    let(:user) { Fabricate(:user) }

    context 'success' do
      let(:new_username) { "#{user.username}1234" }

      before do
        @result = described_class.change(user, new_username)
      end

      it 'returns true' do
        expect(@result).to eq(true)
      end

      it 'should change the username' do
        user.reload
        expect(user.username).to eq(new_username)
      end

      it 'should change the username_lower' do
        user.reload
        expect(user.username_lower).to eq(new_username.downcase)
      end
    end

    context 'failure' do
      let(:wrong_username) { "" }
      let(:username_before_change) { user.username }
      let(:username_lower_before_change) { user.username_lower }

      before do
        @result = described_class.change(user, wrong_username)
      end

      it 'returns false' do
        expect(@result).to eq(false)
      end

      it 'should not change the username' do
        user.reload
        expect(user.username).to eq(username_before_change)
      end

      it 'should not change the username_lower' do
        user.reload
        expect(user.username_lower).to eq(username_lower_before_change)
      end
    end

    describe 'change the case of my username' do
      let!(:myself) { Fabricate(:user, username: 'hansolo') }

      it 'should return true' do
        expect(described_class.change(myself, "HanSolo")).to eq(true)
      end

      it 'should change the username' do
        described_class.change(myself, "HanSolo")
        expect(myself.reload.username).to eq('HanSolo')
      end
    end

    describe 'allow custom minimum username length from site settings' do
      before do
        @custom_min = 2
        SiteSetting.min_username_length = @custom_min
      end

      it 'should allow a shorter username than default' do
        result = described_class.change(user, 'a' * @custom_min)
        expect(result).not_to eq(false)
      end

      it 'should not allow a shorter username than limit' do
        result = described_class.change(user, 'a' * (@custom_min - 1))
        expect(result).to eq(false)
      end

      it 'should not allow a longer username than limit' do
        result = described_class.change(user, 'a' * (User.username_length.end + 1))
        expect(result).to eq(false)
      end
    end
  end

end
