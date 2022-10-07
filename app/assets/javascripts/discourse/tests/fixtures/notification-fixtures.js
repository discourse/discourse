import { NOTIFICATION_TYPES } from "./concerns/notification-types";

export default {
  "/notifications": {
    notifications: [
      {
        id: 5340,
        notification_type: NOTIFICATION_TYPES.edited,
        read: false,
        post_number: 1,
        topic_id: 130,
        slug: "lorem-ipsum-dolor-sit-amet",
        fancy_title: "edited topic 443",
        data: {
          topic_title: "edited topic 443",
          display_username: "velesin",
          revision_number: 1,
          original_post_id: 133,
          original_post_type: 1,
          original_username: "velesin",
        },
      },
      {
        id: 123,
        notification_type: NOTIFICATION_TYPES.replied,
        read: false,
        post_number: 1,
        topic_id: 1234,
        slug: "a-slug",
        fancy_title: "some title",
        data: { topic_title: "some title", display_username: "velesin" },
      },
      {
        id: 456,
        notification_type: NOTIFICATION_TYPES.liked_consolidated,
        read: false,
        data: { display_username: "aquaman", count: "5" },
      },
      {
        id: 789,
        notification_type: NOTIFICATION_TYPES.group_message_summary,
        read: false,
        post_number: null,
        topic_id: null,
        slug: null,
        data: {
          group_id: 41,
          group_name: "test",
          inbox_count: 5,
          username: "test2",
        },
      },
      {
        id: 1234,
        notification_type: NOTIFICATION_TYPES.invitee_accepted,
        read: false,
        post_number: null,
        topic_id: null,
        slug: null,
        data: { display_username: "test1" },
      },
      {
        id: 5678,
        notification_type: NOTIFICATION_TYPES.membership_request_accepted,
        read: false,
        post_number: null,
        topic_id: null,
        slug: null,
        data: { group_id: 41, group_name: "test" },
      },
    ],
  },
};
