/**
 * Recorded server responses, keyed by request URL.
 *
 * @type {Record<string, Record<string, unknown>>}
 */
const userMenuFixtures = {
  "/u/:username/user-menu-bookmarks": {
      notifications: [
        {
          id: 1713,
          user_id: 1,
          notification_type: 24,
          acting_user_avatar_template: "/letter_avatar_proxy/v4/letter/o/f05b48/{size}.png",
          read: false,
          high_priority: true,
          created_at: "2022-08-05T17:27:24.873Z",
          post_number: 1,
          topic_id: 249,
          fancy_title: "Test event hello world!",
          slug: "test-event-hello-world",
          data: {
            title: "Test event hello world!",
            bookmarkable_url: "/t/test-event-hello-world/249/1",
            display_username: "osama",
            bookmark_name: "",
            bookmark_id: 11,
          },
        },
      ],
      bookmarks: [
        {
          id: 6,
          name: "",
          fancy_title: "Test poll topic hello world",
          topic_id: 227,
          bookmarkable_url:
            "http://localhost:4200/t/test-poll-topic-hello-world/227/1",
          user: {
            id: 1,
            username: "osama",
            name: "Osama S",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/o/f05b48/{size}.png",
          },
        },
      ],
  },
  "/u/:username/user-menu-private-messages": {
    unread_notifications: [
      {
        id: 8315,
        user_id: 1,
        notification_type: 6,
        acting_user_avatar_template: "/letter_avatar_proxy/v4/letter/o/f05b48/{size}.png",
        read: false,
        high_priority: true,
        created_at: "2022-08-05T17:27:24.873Z",
        post_number: 1,
        topic_id: 249,
        fancy_title: "Very secret message!",
        slug: "very-secret-message",
        data: {
          topic_title: "very secret message!",
          original_post_id: 1043,
          original_post_type: 1,
          original_username: "osama",
          revision_number: null,
          display_username: "osama"
        },
      },
    ],
    topics: [
      {
        id: 8092,
        slug: "bug-can-not-render-emoji-properly",
        fancy_title: "BUG: Can not render emoji properly :confused:",
        bumped_at: "2019-07-26T01:29:24.177Z",
        highest_post_number: 2,
        last_read_post_number: 2,
        unread_posts: 0,
        last_poster: {
          id: 13,
          username: "mixtape",
          name: "Mix Tape",
          avatar_template: "/letter_avatar_proxy/v4/letter/o/f05b48/{size}.png",
        },
      },
    ],
    read_notifications: [],
  }
};

export default userMenuFixtures;
