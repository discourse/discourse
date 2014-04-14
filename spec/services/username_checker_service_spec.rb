require 'spec_helper'

describe UsernameCheckerService do

  describe 'check_username' do

    before do
      @service = UsernameCheckerService.new
      @nil_email = nil
      @email = 'vincentvega@example.com'
    end

    context 'Username invalid' do
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

      context 'username and email is given' do
        it 'username is available locally but not globally' do
          DiscourseHub.expects(:username_available?).never
          DiscourseHub.expects(:username_match?).returns([false, false, 'porkchop'])
          result = @service.check_username('vincent', @email)
          expected = { available: false, global_match: false, suggestion: 'porkchop' }
          expect(result).to eq(expected)
        end

        it 'username is available both locally and globally' do
          DiscourseHub.expects(:username_available?).never
          DiscourseHub.stubs(:username_match?).returns([true, true, nil])
          result = @service.check_username('vincent', @email)
          expected = { available: true, global_match: true }
          expect(result).to eq(expected)
        end

        it 'username is available locally but not globally' do
          DiscourseHub.stubs(:username_match?).returns([false, false, 'suggestion'])
          result = @service.check_username('vincent', @email)
          expected = { available: false, global_match: false, suggestion: 'suggestion' }
          expect(result).to eq(expected)
        end

        it 'username is available globally but not locally' do
          DiscourseHub.stubs(:username_match?).returns([false, true, nil])
          User.stubs(:username_available?).returns(false)
          UserNameSuggester.stubs(:suggest).returns('einar-j')
          expected = { available: false, suggestion: 'einar-j' }
          result = @service.check_username('vincent', @email)
          expect(result).to eq(expected)
        end

        it 'username not available anywhere' do
          DiscourseHub.stubs(:username_match?).returns([false, false, 'suggestion'])
          expected = { available: false, suggestion: 'suggestion', global_match: false }
          @nil_email = nil
          result = @service.check_username('vincent', @email)
          expect(result).to eq(expected)
        end
      end

      shared_examples "only email is given" do
        it "should call the correct api" do
          DiscourseHub.expects(:username_available?).never
          DiscourseHub.expects(:username_match?).never
          DiscourseHub.stubs(:username_for_email).returns(nil)
          result
        end

        it 'no match on email' do
          DiscourseHub.stubs(:username_for_email).returns(nil)
          result.should == {suggestion: nil}
        end

        it 'match found for email' do
          DiscourseHub.stubs(:username_for_email).returns('vincent')
          result.should == {suggestion: 'vincent'}
        end

        it 'match found for email, but username is taken' do
          # This case can happen when you've already signed up on the site,
          # or enforce_global_nicknames used to be disabled.
          DiscourseHub.stubs(:username_for_email).returns('taken')
          User.stubs(:username_available?).with('taken').returns(false)
          result.should == {suggestion: nil}
        end
      end

      context 'username is nil' do
        subject(:result) { @service.check_username(nil, @email) }
        include_examples "only email is given"
      end

      context 'username is empty string' do
        subject(:result) { @service.check_username('', @email) }
        include_examples "only email is given"
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
