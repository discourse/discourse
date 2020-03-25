export default {
  "/groups.json": {
    groups: [
      {
        id: 41,
        automatic: false,
        name: "discourse",
        user_count: 0,
        alias_level: 0,
        visible: true,
        automatic_membership_email_domains: "",
        automatic_membership_retroactive: false,
        primary_group: false,
        title: null,
        grant_trust_level: null,
        has_messages: false,
        flair_url: null,
        flair_bg_color: null,
        flair_color: null,
        bio_raw: "",
        bio_cooked: null,
        public_admission: true,
        allow_membership_requests: false,
        full_name: "Awesome Team"
      },
      {
        id: 42,
        automatic: false,
        name: "Macdonald",
        user_count: 0,
        alias_level: 99,
        visible: true,
        automatic_membership_email_domains: "",
        automatic_membership_retroactive: false,
        primary_group: false,
        title: null,
        grant_trust_level: null,
        has_messages: false,
        flair_url: null,
        flair_bg_color: null,
        flair_color: null,
        bio_raw: null,
        bio_cooked: null,
        public_admission: false,
        allow_membership_requests: true,
        membership_request_template: "Please add me",
        full_name: null
      }
    ],
    extras: { group_user_ids: [] },
    total_rows_groups: 2,
    load_more_groups: "/groups?page=1"
  },
  "/groups.json?username=eviltrout": {
    groups: [
      {
        id: 41,
        automatic: false,
        name: "discourse",
        user_count: 0,
        alias_level: 0,
        visible: true,
        automatic_membership_email_domains: "",
        automatic_membership_retroactive: false,
        primary_group: false,
        title: null,
        grant_trust_level: null,
        has_messages: false,
        flair_url: null,
        flair_bg_color: null,
        flair_color: null,
        bio_raw: "",
        bio_cooked: null,
        public_admission: true,
        allow_membership_requests: false,
        full_name: "Awesome Team"
      }
    ],
    extras: { group_user_ids: [] },
    total_rows_groups: 1,
    load_more_groups: "/groups?page=1"
  }
};
