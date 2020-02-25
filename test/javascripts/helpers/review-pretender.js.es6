import { set } from "@ember/object";
export default function(helpers) {
  const { response } = helpers;

  let flag = {
    id: 6667,
    type: "ReviewableFlaggedPost",
    score: 3.0,
    target_created_by_id: 1,
    cooked: "<b>cooked content</b>",
    reviewable_score_ids: [1, 2]
  };

  this.get("/review", () => {
    return response(200, {
      reviewables: [
        {
          id: 1234,
          type: "ReviewableUser",
          status: 0,
          version: 0,
          score: 4.0,
          target_created_by_id: 1,
          created_at: "2019-01-14T19:49:53.571Z",
          username: "newbie",
          email: "newbie@example.com",
          bundled_action_ids: ["approve", "reject"]
        },
        {
          id: 4321,
          type: "ReviewableQueuedPost",
          status: 0,
          score: 4.0,
          created_at: "2019-01-14T19:49:53.571Z",
          target_created_by_id: 1,
          payload: {
            raw: "existing body",
            tags: ["hello", "world"]
          },
          version: 1,
          can_edit: true,
          editable_fields: [
            { id: "category_id", type: "category" },
            { id: "payload.title", type: "text" },
            { id: "payload.raw", type: "textarea" },
            { id: "payload.tags", type: "tags" }
          ],
          bundled_action_ids: ["approve", "reject"]
        },
        flag
      ],
      bundled_actions: [
        {
          id: "approve",
          action_ids: ["approve"]
        },
        {
          id: "reject",
          action_ids: ["reject"]
        }
      ],
      actions: [
        {
          id: "approve",
          label: "Approve",
          icon: "far-thumbs-up"
        },
        {
          id: "reject",
          label: "Reject",
          icon: "far-thumbs-down"
        }
      ],
      reviewable_scores: [{ id: 1 }, { id: 2 }],
      users: [{ id: 1, username: "eviltrout" }],
      meta: {
        total_rows_reviewables: 2,
        types: {
          created_by: "user",
          target_created_by: "user"
        }
      },
      __rest_serializer: "1"
    });
  });

  this.get("/review/topics", () => {
    return response(200, {
      reviewable_topics: [{ id: 1234, title: "Cool topic" }]
    });
  });

  this.get("/review/settings", () => {
    return response(200, {
      reviewable_score_types: [
        {
          id: 3,
          title: "Off-Topic",
          reviewable_priority: 0
        },
        {
          id: 4,
          title: "Inappropriate",
          reviewable_priority: 5
        }
      ],
      reviewable_settings: {
        id: 13870,
        reviewable_score_type_ids: [3, 4],
        reviewable_priorities: [
          { id: 0, name: "Low" },
          { id: 5, name: "Medium" },
          { id: 10, name: "High" }
        ]
      },
      __rest_serializer: "1"
    });
  });

  this.put("/review/settings", () => response(200, {}));

  this.get("/review/:id", () => {
    return response(200, {
      reviewable: flag
    });
  });

  this.put("/review/:id/perform/:actionId", request => {
    return response(200, {
      reviewable_perform_result: {
        success: true,
        remove_reviewable_ids: [parseInt(request.params.id, 10)]
      }
    });
  });

  this.put("/review/:id", request => {
    let result = { payload: {} };
    Object.entries(JSON.parse(request.requestBody).reviewable).forEach(t => {
      set(result, t[0], t[1]);
    });
    return response(200, result);
  });
}
