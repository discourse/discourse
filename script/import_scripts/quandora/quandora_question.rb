require 'json'
require 'cgi'
require 'time'

class QuandoraQuestion

  def initialize(question_json)
    @question = JSON.parse question_json
  end

  def topic
    topic = {}
    topic[:id] = @question['uid']
    topic[:author_id] = @question['author']['uid']
    topic[:title] = unescape @question['title']
    topic[:raw] = unescape @question['content']
    topic[:created_at] = Time.parse @question['created']
    topic
  end

  def users
    users = {}
    user = user_from_author @question['author']
    users[user[:id]] = user
    replies.each do |reply|
      user = user_from_author reply[:author]
      users[user[:id]] = user
    end
    users.values.to_a
  end

  def user_from_author(author)
    email = author['email']
    email = "#{author['uid']}@noemail.com" unless email

    user = {}
    user[:id] = author['uid']
    user[:name] = "#{author['firstName']} #{author['lastName']}"
    user[:email] = email
    user[:staged] = true
    user
  end

  def replies
    posts = []
    answers = @question['answersList']
    comments = @question['comments']
    comments.each_with_index do |comment, i|
      posts << post_from_comment(comment, i, @question)
    end
    answers.each do |answer|
      posts << post_from_answer(answer)
      comments = answer['comments']
      comments.each_with_index do |comment, i|
        posts << post_from_comment(comment, i, answer)
      end
    end
    order_replies posts
  end

  def order_replies(posts)
    posts = posts.sort_by { |p| p[:created_at] }
    posts.each_with_index do |p, i|
      p[:post_number] = i + 2
    end
    posts.each do |p|
      parent = posts.select { |pp| pp[:id] == p[:parent_id] }
      p[:reply_to_post_number] = parent[0][:post_number] if parent.size > 0
    end
    posts
  end

  def post_from_answer(answer)
    post = {}
    post[:id] = answer['uid']
    post[:parent_id] = @question['uid']
    post[:author] = answer['author']
    post[:author_id] = answer['author']['uid']
    post[:raw] = unescape answer['content']
    post[:created_at] = Time.parse answer['created']
    post
  end

  def post_from_comment(comment, index, parent)
    if comment['created']
      created_at = Time.parse comment['created']
    else
      created_at = Time.parse parent['created']
    end
    parent_id = parent['uid']
    parent_id = "#{parent['uid']}-#{index - 1}" if index > 0
    post = {}
    id = "#{parent['uid']}-#{index}"
    post[:id] = id
    post[:parent_id] = parent_id
    post[:author] = comment['author']
    post[:author_id] = comment['author']['uid']
    post[:raw] = unescape comment['text']
    post[:created_at] = created_at
    post
  end

   private

  def unescape(html)
    return nil unless html
    CGI.unescapeHTML html
  end
end
