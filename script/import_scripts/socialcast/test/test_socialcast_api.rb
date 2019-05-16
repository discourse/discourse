# frozen_string_literal: true

require 'minitest/autorun'
require 'yaml'
require_relative '../socialcast_api.rb'
require_relative './test_data.rb'

class TestSocialcastApi < Minitest::Test

  DEBUG = false

  def initialize(args)
    config = YAML::load_file(File.join(__dir__, 'config.ex.yml'))
    @domain = config['domain']
    @username = config['username']
    @password = config['password']
    @kb_id = config['kb_id']
    @question_id = config['question_id']
    super args
  end

  def setup
    @socialcast = SocialcastApi.new @domain, @username, @password
  end

  def test_intialize
    assert_equal @domain, @socialcast.domain
    assert_equal @username, @socialcast.username
    assert_equal @password, @socialcast.password
  end

  def test_base_url
    assert_equal 'https://demo.socialcast.com/api', @socialcast.base_url
  end

  def test_headers
    headers = @socialcast.headers
    assert_equal 'Basic ZW1pbHlAc29jaWFsY2FzdC5jb206ZGVtbw==', headers[:Authorization]
    assert_equal 'application/json', headers[:Accept]
  end

  def test_list_users
    users = @socialcast.list_users
    expected = JSON.parse(USERS)['users'].sort { |u| u['id'] }
    assert_equal 15, users.size
    assert_equal expected[0], users[0]
  end

  def test_list_users_next_page
    users = @socialcast.list_users(page: 2)
    assert_equal 0, users.size
  end

  def test_list_messages
    messages = @socialcast.list_messages
    expected = JSON.parse(MESSAGES)['messages'].sort { |m| m['id'] }
    assert_equal 20, messages.size
    check_keys expected[0], messages[0]
  end

  def test_messages_next_page
    messages = @socialcast.list_messages(page: 2)
    expected = JSON.parse(MESSAGES_PG_2)['messages'].sort { |m| m['id'] }
    assert_equal 20, messages.size
    check_keys expected[0], messages[0]
  end

  private

  def check_keys(expected, actual)
    msg = "### caller[0]:\nKey not found in actual keys: #{actual.keys}\n"
    expected.keys.each do |k|
      assert (actual.keys.include? k), "#{k}"
    end
  end

  def debug(message, show = false)
    if show || DEBUG
      puts '### ' + caller[0]
      puts ''
      puts message
      puts ''
      puts ''
    end
  end
end
