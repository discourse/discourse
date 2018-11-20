require 'minitest/autorun'
require 'cgi'
require 'time'
require_relative '../quandora_question.rb'
require_relative './test_data.rb'

class TestQuandoraQuestion < Minitest::Test

  def setup
    @data = JSON.parse(QUESTION)['data']
    @question = QuandoraQuestion.new @data.to_json
  end

  def test_topic
    topic = @question.topic
    assert_equal @data['uid'], topic[:id]
    assert_equal @data['author']['uid'], topic[:author_id]
    assert_equal unescape(@data['title']), topic[:title]
    assert_equal unescape(@data['content']), topic[:raw]
    assert_equal Time.parse(@data['created']), topic[:created_at]
  end

  def test_user_from_author
    author = {}
    author['uid'] = 'uid'
    author['firstName'] = 'Joe'
    author['lastName'] = 'Schmoe'
    author['email'] = 'joe.schmoe@mydomain.com'

    user = @question.user_from_author author

    assert_equal 'uid', user[:id]
    assert_equal 'Joe Schmoe', user[:name]
    assert_equal 'joe.schmoe@mydomain.com', user[:email]
    assert_equal true, user[:staged]
  end

  def test_user_from_author_with_no_email
    author = {}
    author['uid'] = 'foo'
    user = @question.user_from_author author
    assert_equal 'foo@noemail.com', user[:email]
  end

  def test_replies
    replies = @question.replies
    assert_equal 5, replies.size
    assert_equal 2, replies[0][:post_number]
    assert_equal 3, replies[1][:post_number]
    assert_equal 4, replies[2][:post_number]
    assert_equal 5, replies[3][:post_number]
    assert_equal 6, replies[4][:post_number]
    assert_equal nil, replies[0][:reply_to_post_number]
    assert_equal nil, replies[1][:reply_to_post_number]
    assert_equal nil, replies[2][:reply_to_post_number]
    assert_equal 4, replies[3][:reply_to_post_number]
    assert_equal 3, replies[4][:reply_to_post_number]
    assert_equal '2013-01-07 04:59:56 UTC', replies[0][:created_at].to_s
    assert_equal '2013-01-08 16:49:32 UTC', replies[1][:created_at].to_s
    assert_equal '2016-01-20 15:38:55 UTC', replies[2][:created_at].to_s
    assert_equal '2016-01-21 15:38:55 UTC', replies[3][:created_at].to_s
    assert_equal '2016-01-22 15:38:55 UTC', replies[4][:created_at].to_s
  end

  def test_post_from_answer
    answer = {}
    answer['uid'] = 'uid'
    answer['content'] = 'content'
    answer['created'] = '2013-01-06T18:24:54.62Z'
    answer['author'] = { 'uid' => 'auid' }

    post = @question.post_from_answer answer

    assert_equal 'uid', post[:id]
    assert_equal @question.topic[:id], post[:parent_id]
    assert_equal answer['author'], post[:author]
    assert_equal 'auid', post[:author_id]
    assert_equal 'content', post[:raw]
    assert_equal Time.parse('2013-01-06T18:24:54.62Z'), post[:created_at]
  end

  def test_post_from_comment
    comment = {}
    comment['text'] = 'text'
    comment['created'] = '2013-01-06T18:24:54.62Z'
    comment['author'] = { 'uid' => 'auid' }
    parent = { 'uid' => 'parent-uid' }

    post = @question.post_from_comment comment, 0, parent

    assert_equal 'parent-uid-0', post[:id]
    assert_equal 'parent-uid', post[:parent_id]
    assert_equal comment['author'], post[:author]
    assert_equal 'auid', post[:author_id]
    assert_equal 'text', post[:raw]
    assert_equal Time.parse('2013-01-06T18:24:54.62Z'), post[:created_at]
  end

  def test_post_from_comment_uses_parent_created_if_necessary
    comment = {}
    comment['author'] = { 'uid' => 'auid' }
    parent = { 'created' => '2013-01-06T18:24:54.62Z' }

    post = @question.post_from_comment comment, 0, parent

    assert_equal Time.parse('2013-01-06T18:24:54.62Z'), post[:created_at]
  end

  def test_post_from_comment_uses_previous_comment_as_parent
    comment = {}
    comment['author'] = { 'uid' => 'auid' }
    parent = { 'uid' => 'parent-uid', 'created' => '2013-01-06T18:24:54.62Z' }

    post = @question.post_from_comment comment, 1, parent

    assert_equal 'parent-uid-1', post[:id]
    assert_equal 'parent-uid-0', post[:parent_id]
    assert_equal Time.parse('2013-01-06T18:24:54.62Z'), post[:created_at]
  end

  def test_users
    users = @question.users
    assert_equal 5, users.size
    assert_equal 'Ida Inquisitive', users[0][:name]
    assert_equal 'Harry Helpful', users[1][:name]
    assert_equal 'Sam Smarty-Pants', users[2][:name]
    assert_equal 'Greta Greatful', users[3][:name]
    assert_equal 'Eddy Excited', users[4][:name]
  end

  private

  def unescape(html)
    CGI.unescapeHTML html
  end
end
