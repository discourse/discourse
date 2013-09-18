require 'spec_helper'

describe UsernameCheckerService do

  describe 'check_username' do

    before do
      @service = UsernameCheckerService.new
      @nil_email = nil
      @email = 'vincentvega@example.com'
    end

    context 'Username invalid' do
      it 'rejects blank usernames' do
        result = @service.check_username('',  @nil_email)
        expect(result).to have_key(:errors)
      end
      it 'rejects too short usernames' do
        result = @service.check_username('a', @nil_email)
        expect(result).to have_key(:errors)
      end
      it 'rejects too long usernames' do
        result = @service.check_username('a123456789b123456789c123456789', @nil_email)
        expect(result).to have_key(:errors)
      end

      it 'rejects usernames with invalid characters' do
        result = @service.check_username('vincent-', @nil_email)
        expect(result).to have_key(:errors)
      end

      it 'rejects usernames that do not start with an alphanumeric character' do
        result = @service.check_username('_vincent', @nil_email)
        expect(result).to have_key(:errors)
      end
    end

    context 'Using Discourse Hub' do
      before do
        SiteSetting.stubs(:call_discourse_hub?).returns(true)
      end

      context 'and email is given' do
        it 'username is available locally but not globally' do
          DiscourseHub.stubs(:nickname_available?).returns([false, 'suggestion'])
          DiscourseHub.stubs(:nickname_match?).returns([true, false, nil])
          result = @service.check_username('vincent', @email)
          expected = { available: true, global_match: true }
          expect(result).to eq(expected)
        end

      end

      it 'username is available both locally and globally' do
        DiscourseHub.stubs(:nickname_available?).returns([true, nil])
        DiscourseHub.stubs(:nickname_match?).returns([false, true, nil])
        result = @service.check_username('vincent', @email)
        expected = { available: true, global_match: false }
        expect(result).to eq(expected)
      end

      it 'username is available locally but not globally' do
        DiscourseHub.stubs(:nickname_match?).returns([false, true, nil])
        result = @service.check_username('vincent', @email)
        expected = { available: true, global_match: false }
        expect(result).to eq(expected)
      end

      it 'username is available globally but not locally' do
        DiscourseHub.stubs(:nickname_match?).returns([false, true, nil])
        User.stubs(:username_available?).returns(false)
        UserNameSuggester.stubs(:suggest).returns('einar-j')
        expected = { available: false, suggestion: 'einar-j' }
        result = @service.check_username('vincent', @email)
        expect(result).to eq(expected)
      end

      it 'username not available anywhere' do
        DiscourseHub.stubs(:nickname_match?).returns([false, false, 'suggestion'])
        expected = { available: false, suggestion: 'suggestion', global_match: false }
        @nil_email = nil
        result = @service.check_username('vincent', @email)
        expect(result).to eq(expected)
      end
    end

    context 'Discourse Hub disabled' do
      it 'username not available locally' do
        User.stubs(:username_available?).returns(false)
        UserNameSuggester.stubs(:suggest).returns('einar-j')
        result = @service.check_username('vincent', @nil_email)
        result[:available].should be_false
        result[:suggestion].should eq('einar-j')
      end

      it 'username available locally' do
        User.stubs(:username_available?).returns(true)
        result = @service.check_username('vincent', @nil_email)
        result[:available].should be_true
      end
    end
  end

end
