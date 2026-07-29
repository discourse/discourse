# frozen_string_literal: true

module DiscourseSolvedStructuredDataHelper
  def solved_answer_json(post:)
    '{"@type":"Answer","author":{"@type":"Person","name":"%{username2}","url":"%{user2_url}"},"dateModified":"%{answer_modified}","datePublished":"%{answered_at}","text":"%{answer_text}","upvoteCount":%{answer_likes},"url":"%{answer_url}"}' %
      {
        answer_text: post.excerpt,
        answer_likes: post.like_count,
        answered_at: post.created_at.as_json,
        answer_modified: (post.last_version_at || post.created_at).as_json,
        answer_url: post.full_url,
        username2: post.user&.username,
        user2_url: post.user&.full_url,
      }
  end

  def solved_schema_json(topic:, first_post:, answers_json:, answer_count: 1)
    '<script type="application/ld+json">{"@context":"http://schema.org","@type":"QAPage","name":"%{title}","datePublished":"%{created_at}","mainEntity":{"@type":"Question","answerCount":%{answer_count},"author":{"@type":"Person","name":"%{username1}","url":"%{user1_url}"},"dateModified":"%{question_modified}","datePublished":"%{created_at}","name":"%{title}","text":"%{question_text}","upvoteCount":%{question_likes}%{answer_json}}}</script>' %
      {
        answer_count:,
        title: topic.title,
        question_text: first_post.excerpt,
        question_likes: first_post.like_count,
        created_at: topic.created_at.as_json,
        question_modified: (first_post.last_version_at || first_post.created_at).as_json,
        username1: topic.user&.username,
        user1_url: topic.user&.full_url,
        answer_json: answers_json,
      }
  end

  def parse_crawler_body(body:)
    Nokogiri::HTML5.fragment(body)
  end
end
