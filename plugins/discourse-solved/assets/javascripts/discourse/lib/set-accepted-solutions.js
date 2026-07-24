export default function setAcceptedSolutions(topic, acceptedAnswers) {
  const acceptedPostNumbers = new Set(
    acceptedAnswers?.map((answer) => answer.post_number)
  );

  const topicHasAcceptedAnswer = acceptedPostNumbers.size > 0;

  topic.accepted_answers = acceptedAnswers;
  topic.has_accepted_answer = topicHasAcceptedAnswer;

  const posts = new Set(topic.postStream?.posts);
  topic.postStream?.loadedPosts?.forEach((post) => posts.add(post));

  posts.forEach((post) => {
    if (post.post_number === 1) {
      return;
    }

    post.setProperties({
      accepted_answer: acceptedPostNumbers.has(post.post_number),
      topic_accepted_answer: topicHasAcceptedAnswer,
    });
  });
}
