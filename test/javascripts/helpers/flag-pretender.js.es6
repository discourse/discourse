export default function(helpers) {
  const { response, success } = helpers;

  const eviltrout = {
    id: 1,
    username: "eviltrout",
    avatar_template: "/images/avatar.png"
  };
  const sam = {
    id: 2,
    username: "sam",
    avatar_template: "/images/avatar.png",
    can_delete_all_posts: true,
    can_be_deleted: true,
    post_count: 1,
    topic_count: 0
  };

  this.get("/admin/flagged_topics", () => {
    return response(200, {
      flagged_topics: [
        {
          id: 280,
          user_ids: [eviltrout.id, sam.id],
          flag_counts: [
            { flag_type_id: 1, count: 3 },
            { flag_type_id: 2, count: 2 },
            { flag_type_id: 3, count: 1 }
          ]
        }
      ],
      users: [eviltrout, sam],
      __rest_serializer: "1"
    });
  });

  this.get("/admin/flags/active.json", () => {
    return response(200, {
      flagged_posts: [
        {
          id: 1,
          user_id: sam.id,
          post_action_ids: [1]
        }
      ],
      users: [eviltrout, sam],
      topics: [],
      post_actions: [
        {
          id: 1,
          user_id: eviltrout.id,
          post_action_type_id: 8,
          name_key: "spam",
          conversation: {
            response: {
              user_id: eviltrout.id,
              excerpt: "hello"
            },
            reply: {
              user_id: eviltrout.id,
              excerpt: "goodbye"
            }
          }
        }
      ],
      __rest_serializer: "1"
    });
  });

  this.post("/admin/flags/agree/1", success);
  this.post("/admin/flags/defer/1", success);
  this.post("/admin/flags/disagree/1", success);
}
