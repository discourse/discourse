import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";

export default function topicWithAssignedPosts() {
  const username = "eviltrout";
  const topic = cloneJSON(topicFixtures["/t/28830/1.json"]);
  const firstReply = topic.post_stream.posts[1];
  const secondReply = topic.post_stream.posts[2];

  topic["indirectly_assigned_to"] = {
    [firstReply.id]: {
      assigned_to: {
        username,
      },
      post_number: 1,
    },
    [secondReply.id]: {
      assigned_to: {
        username,
      },
      post_number: 2,
    },
  };
  firstReply["assigned_to_user"] = { username };
  secondReply["assigned_to_user"] = { username };

  return topic;
}
