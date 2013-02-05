require 'spec_helper'
require_dependency 'mothership'

describe Mothership do
  describe '#nickname_available?' do
    it 'should return true when nickname is available and no suggestion' do
      RestClient.stubs(:get).returns( {success: 'OK', available: true}.to_json )
      Mothership.nickname_available?('MacGyver').should == [true, nil]
    end

    it 'should return false and a suggestion when nickname is not available' do
      RestClient.stubs(:get).returns( {success: 'OK', available: false, suggestion: 'MacGyver1'}.to_json )
      available, suggestion = Mothership.nickname_available?('MacGyver')
      available.should be_false
      suggestion.should_not be_nil
    end

    # How to handle connect errors? timeout? 401? 403? 429?
  end

  describe '#nickname_match?' do
    it 'should return true when it is a match and no suggestion' do
      RestClient.stubs(:get).returns( {success: 'OK', match: true, available: false}.to_json )
      Mothership.nickname_match?('MacGyver', 'macg@example.com').should == [true, false, nil]
    end

    it 'should return false and a suggestion when it is not a match and the nickname is not available' do
      RestClient.stubs(:get).returns( {success: 'OK', match: false, available: false, suggestion: 'MacGyver1'}.to_json )
      match, available, suggestion = Mothership.nickname_match?('MacGyver', 'macg@example.com')
      match.should be_false
      available.should be_false
      suggestion.should_not be_nil
    end

    it 'should return false and no suggestion when it is not a match and the nickname is available' do
      RestClient.stubs(:get).returns( {success: 'OK', match: false, available: true}.to_json )
      match, available, suggestion = Mothership.nickname_match?('MacGyver', 'macg@example.com')
      match.should be_false
      available.should be_true
      suggestion.should be_nil
    end
  end

  describe '#register_nickname' do
    it 'should return true when registration succeeds' do
      RestClient.stubs(:post).returns( {success: 'OK'}.to_json )
      Mothership.register_nickname('MacGyver', 'macg@example.com').should be_true
    end

    it 'should return raise an exception when registration fails' do
      RestClient.stubs(:post).returns( {failed: -200}.to_json )
      expect {
        Mothership.register_nickname('MacGyver', 'macg@example.com')
      }.to raise_error(Mothership::NicknameUnavailable)
    end
  end

  describe '#current_discourse_version' do
    it 'should return the latest version of discourse' do
      RestClient.stubs(:get).returns( {success: 'OK', version: 1.0}.to_json )
      Mothership.current_discourse_version().should == 1.0
    end
  end
end
