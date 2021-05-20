export default {
  "/user_badges": {
    badges: [
      {
        id: 874,
        name: "Badge 2",
        description: null,
        badge_type_id: 7
      }
    ],
    badge_types: [
      {
        id: 7,
        name: "Silver 2"
      }
    ],
    users: [
      {
        id: 13470,
        username: "anne3",
        avatar_template:
          "//www.gravatar.com/avatar/a4151b1fd72089c54e2374565a87da7f.png?s={size}\u0026r=pg\u0026d=identicon"
      }
    ],
    user_badge: {
      id: 665,
      granted_at: "2014-03-09T20:30:01.190-04:00",
      badge_id: 874,
      granted_by_id: 13470
    }
  },
  "/user-badges/:username": {
    badges: [
      {
        id: 880,
        name: "Badge 8",
        description: null,
        badge_type_id: 13
      },
      {
        id: 50,
        name: "CustomBadge",
        description: null,
        allow_title: true,
        badge_type_id: 3
      }
    ],
    badge_types: [
      {
        id: 13,
        name: "Silver 8"
      }
    ],
    users: [],
    user_badges: [
      {
        id: 668,
        granted_at: "2014-03-09T20:30:01.420-04:00",
        badge_id: 880,
        granted_by_id: null
      },
      {
        id: 669,
        granted_at: "2014-03-09T20:30:01.420-04:00",
        badge_id: 50,
        granted_by_id: null
      }
    ]
  }
};
