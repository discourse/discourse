/*jshint maxlen:10000000 */
import { NOTIFICATION_TYPES } from "fixtures/concerns/notification-types";

export default {
  "/notifications": {
    notifications: [
      {
        id: 123,
        notification_type: NOTIFICATION_TYPES.replied,
        read: false,
        post_number: 2,
        topic_id: 1234,
        slug: "a-slug",
        data: { topic_title: "some title", display_username: "velesin" }
      },
      {
        id: 456,
        notification_type: NOTIFICATION_TYPES.liked_consolidated,
        read: false,
        data: { display_username: "aquaman", count: "5" }
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
          username: "test2"
        }
      },
      {
        id: 1234,
        notification_type: NOTIFICATION_TYPES.invitee_accepted,
        read: false,
        post_number: null,
        topic_id: null,
        slug: null,
        data: { display_username: "test1" }
      },
      {
        id: 5678,
        notification_type: NOTIFICATION_TYPES.membership_request_accepted,
        read: false,
        post_number: null,
        topic_id: null,
        slug: null,
        data: { group_id: 41, group_name: "test" }
      }
    ]
  }
};
