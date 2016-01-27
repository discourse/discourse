require 'minitest/autorun'
require 'yaml'
require_relative '../quandora_api.rb'
require_relative './test_data.rb'

class TestQuandoraApi < Minitest::Test

  DEBUG = false

  def initialize args
    config = YAML::load_file(File.join(__dir__, 'config.yml'))
    @domain = config['domain']
    @username = config['username']
    @password = config['password']
    @kb_id = config['kb_id']
    @question_id = config['question_id']
    super args
  end

  def setup
    @quandora = QuandoraApi.new @domain, @username, @password
  end

  def test_intialize
    assert_equal @domain, @quandora.domain
    assert_equal @username, @quandora.username
    assert_equal @password, @quandora.password
  end

  def test_base_url
    assert_equal 'https://mydomain.quandora.com/m/json', @quandora.base_url('mydomain')
  end

  def test_auth_header
    user = 'Aladdin'
    password = 'open sesame'
    auth_header = @quandora.auth_header user, password
    assert_equal 'Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==', auth_header[:Authorization]
  end

  def test_list_bases_element_has_expected_structure
    element = @quandora.list_bases[0]
    expected = JSON.parse(BASES)['data'][0]
    debug element
    check_keys expected, element
  end

  def test_list_questions_has_expected_structure
    response = @quandora.list_questions @kb_id, 1
    debug response
    check_keys JSON.parse(QUESTIONS)['data']['result'][0], response[0]
  end

  def test_get_question_has_expected_structure
    question = @quandora.get_question @question_id 
    expected = JSON.parse(QUESTION)['data']
    check_keys expected, question

    expected_comment = expected['comments'][0]
    actual_comment = question['comments'][0]
    check_keys expected_comment, actual_comment

    expected_answer = expected['answersList'][1]
    actual_answer = question['answersList'][0]
    check_keys expected_answer, actual_answer

    expected_answer_comment = expected_answer['comments'][0]
    actual_answer_comment = actual_answer['comments'][0]
    check_keys expected_answer_comment, actual_answer_comment
  end

  private

  def check_keys expected, actual
    msg = "### caller[0]:\nKey not found in actual keys: #{actual.keys}\n"
    expected.keys.each do |k|
      assert (actual.keys.include? k), "#{k}"
    end
  end

  def debug message, show=false
    if show || DEBUG
      puts '### ' + caller[0]
      puts ''
      puts message
      puts ''
      puts ''
    end
  end
end
