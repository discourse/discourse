import PreloadStore from "preload-store";

/*jshint maxlen:10000000 */
PreloadStore.store("site", {
  default_archetype: "regular",
  notification_types: {
    mentioned: 1,
    replied: 2,
    quoted: 3,
    edited: 4,
    liked: 5,
    private_message: 6,
    invited_to_private_message: 7,
    invitee_accepted: 8,
    posted: 9,
    moved_post: 10
  },
  post_types: { regular: 1, moderator_action: 2 },
  groups: [
    { id: 0, name: "everyone" },
    { id: 1, name: "admins" },
    { id: 2, name: "moderators" },
    { id: 3, name: "staff" },
    { id: 10, name: "trust_level_0" },
    { id: 11, name: "trust_level_1" },
    { id: 12, name: "trust_level_2" },
    { id: 13, name: "trust_level_3" },
    { id: 14, name: "trust_level_4" },
    { id: 20, name: "ubuntu" },
    { id: 21, name: "test" }
  ],
  filters: ["latest", "unread", "new", "starred", "read", "posted"],
  periods: ["yearly", "monthly", "weekly", "daily"],
  top_menu_items: [
    "latest",
    "unread",
    "new",
    "starred",
    "read",
    "posted",
    "category",
    "categories",
    "top"
  ],
  anonymous_top_menu_items: ["latest", "category", "categories", "top"],
  uncategorized_category_id: 17,
  categories: [
    {
      id: 5,
      name: "extensibility",
      color: "FE8432",
      text_color: "FFFFFF",
      slug: "extensibility",
      topic_count: 102,
      description:
        "Topics about extending the functionality of Discourse with plugins, themes, add-ons, or other mechanisms for extensibility.  ",
      topic_url: "/t/category-definition-for-extensibility/28",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 7,
      name: "dev",
      color: "000",
      text_color: "FFFFFF",
      slug: "dev",
      topic_count: 284,
      description:
        "This category is for topics related to hacking on Discourse: submitting pull requests, configuring development environments, coding conventions, and so forth.",
      topic_url: "/t/category-definition-for-dev/1026",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 1,
      name: "bug",
      color: "e9dd00",
      text_color: "000000",
      slug: "bug",
      topic_count: 660,
      description:
        "Bug reports on Discourse. Do be sure to search prior to submitting bugs. Include repro steps, and only describe one bug per topic please.",
      topic_url: "/t/category-definition-for-bug/2",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 8,
      name: "hosting",
      color: "74CCED",
      text_color: "FFFFFF",
      slug: "hosting",
      topic_count: 69,
      description:
        "Topics about hosting Discourse, either on your own servers, in the cloud, or with specific hosting services.",
      topic_url: "/t/category-definition-for-hosting/2626",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 6,
      name: "support",
      color: "b99",
      text_color: "FFFFFF",
      slug: "support",
      topic_count: 782,
      description:
        "Support on configuring, using, and installing Discourse. Not for software development related topics, but for admins and end users configuring and using Discourse.",
      topic_url: "/t/category-definition-for-support/389",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 2,
      name: "feature",
      color: "0E76BD",
      text_color: "FFFFFF",
      slug: "feature",
      topic_count: 727,
      description:
        "Discussion about features or potential features of Discourse: how they work, why they work, etc.",
      topic_url: "/t/category-definition-for-feature/11",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 13,
      name: "blog",
      color: "ED207B",
      text_color: "FFFFFF",
      slug: "blog",
      topic_count: 14,
      description:
        "Discussion topics generated from the official Discourse Blog. These topics are linked from the bottom of each blog entry where the blog comments would normally be.",
      topic_url: "/t/category-definition-for-blog/5250",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 12,
      name: "discourse hub",
      color: "b2c79f",
      text_color: "FFFFFF",
      slug: "discourse-hub",
      topic_count: 4,
      description:
        "Topics about current or future Discourse Hub functionality at discourse.org including nickname registration, global user pages, and the site directory.",
      topic_url: "/t/category-definition-for-discourse-hub/3038",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 11,
      name: "login",
      color: "edb400",
      text_color: "FFFFFF",
      slug: "login",
      topic_count: 27,
      description:
        "Topics about logging in to Discourse, using any standard third party provider (Twitter, Facebook, Google), traditional username and password, or with a custom plugin.",
      topic_url: "/t/category-definition-for-login/2828",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 3,
      name: "meta",
      color: "aaa",
      text_color: "FFFFFF",
      slug: "meta",
      topic_count: 79,
      description:
        "Discussion about meta.discourse.org itself, the organization of this forum about Discourse, how it works, and how we can improve this site.",
      topic_url: "/t/category-definition-for-meta/24",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 10,
      name: "howto",
      color: "76923C",
      text_color: "FFFFFF",
      slug: "howto",
      topic_count: 58,
      description:
        "Tutorial topics that describe how to set up, configure, or install Discourse using a specific platform or environment. Topics in this category may only be created by trust level 2 and up. ",
      topic_url: "/t/category-definition-for-howto/2629",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 14,
      name: "marketplace",
      color: "8C6238",
      text_color: "FFFFFF",
      slug: "marketplace",
      topic_count: 24,
      description:
        "About commercial Discourse related stuff: jobs or paid gigs, plugins, themes, hosting, etc.",
      topic_url: "/t/category-definition-for-marketplace/5425",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 17,
      name: "uncategorized",
      color: "AB9364",
      text_color: "FFFFFF",
      slug: "uncategorized",
      topic_count: 229,
      description: "",
      topic_url: null,
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 9,
      name: "ux",
      color: "5F497A",
      text_color: "FFFFFF",
      slug: "ux",
      topic_count: 184,
      description:
        "Discussion about the user interface of Discourse, how features are presented to the user in the client, including language and UI elements.",
      topic_url: "/t/category-definition-for-ux/2628",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    },
    {
      id: 4,
      name: "faq",
      color: "33b",
      text_color: "FFFFFF",
      slug: "faq",
      topic_count: 49,
      description:
        "Topics that come up very often when discussing Discourse will eventually be classified into this Frequently Asked Questions category. Should only be added to popular topics.",
      topic_url: "/t/category-definition-for-faq/25",
      hotness: 5.0,
      read_restricted: false,
      permission: null
    }
  ],
  post_action_types: [
    {
      name_key: "bookmark",
      name: "Bookmark",
      description: "Bookmark this post",
      long_form: "bookmarked this post",
      is_flag: false,
      icon: null,
      id: 1,
      is_custom_flag: false
    },
    {
      name_key: "like",
      name: "Like",
      description: "Like this post",
      long_form: "liked this",
      is_flag: false,
      icon: "heart",
      id: 2,
      is_custom_flag: false
    },
    {
      name_key: "off_topic",
      name: "Off-Topic",
      description:
        "This post is radically off-topic in the current conversation, and should probably be moved to a different topic. If this is a topic, perhaps it does not belong here.",
      long_form: "flagged this as off-topic",
      is_flag: true,
      icon: null,
      id: 3,
      is_custom_flag: false
    },
    {
      name_key: "inappropriate",
      name: "Inappropriate",
      description:
        'This post contains content that a reasonable person would consider offensive, abusive, or a violation of <a href="/faq">our community guidelines</a>.',
      long_form: "flagged this as inappropriate",
      is_flag: true,
      icon: null,
      id: 4,
      is_custom_flag: false
    },
    {
      name_key: "vote",
      name: "Vote",
      description: "Vote for this post",
      long_form: "voted for this post",
      is_flag: false,
      icon: null,
      id: 5,
      is_custom_flag: false
    },
    {
      name_key: "spam",
      name: "Spam",
      description:
        "This post is an advertisement. It is not useful or relevant to the current conversation, but promotional in nature.",
      long_form: "flagged this as spam",
      is_flag: true,
      icon: null,
      id: 8,
      is_custom_flag: false
    },
    {
      name_key: "notify_user",
      name: "Notify {{username}}",
      description:
        "This post contains something I want to talk to this person directly and privately about.",
      long_form: "notified user",
      is_flag: true,
      icon: null,
      id: 6,
      is_custom_flag: true
    },
    {
      name_key: "notify_moderators",
      name: "Notify moderators",
      description:
        'This post requires general moderator attention based on the <a href="/faq">FAQ</a>, <a href="/tos">TOS</a>, or for another reason not listed above.',
      long_form: "notified moderators",
      is_flag: true,
      icon: null,
      id: 7,
      is_custom_flag: true
    }
  ],
  trust_levels: [
    { id: 0, name: "new user" },
    { id: 1, name: "basic user" },
    { id: 2, name: "member" },
    { id: 3, name: "regular" },
    { id: 4, name: "leader" }
  ],
  archetypes: [{ id: "regular", name: "Regular Topic", options: [] }]
});
