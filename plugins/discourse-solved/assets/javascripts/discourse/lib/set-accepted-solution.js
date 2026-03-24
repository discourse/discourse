export default function setAcceptedSolution(topic, acceptedAnswer) {
  topic.postStream?.posts?.forEach((post) => {
    if (!acceptedAnswer) {
      post.setProperties({
        accepted_answer: false,
        topic_accepted_answer: false,
      });
    } else if (post.post_number > 1) {
      post.setProperties(
        acceptedAnswer.post_number === post.post_number
          ? {
              accepted_answer: true,
              topic_accepted_answer: true,
            }
          : {
              accepted_answer: false,
              topic_accepted_answer: true,
            }
      );
    }
  });

  topic.accepted_answer = acceptedAnswer;
  topic.has_accepted_answer = !!acceptedAnswer;
}
