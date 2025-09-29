import NavItem from "discourse/models/nav-item";

let topicId = 2000000;
let userId = 1000000;

let _data;

export function createData(store) {
  if (_data) {
    return _data;
  }

  let categories = [
    {
      id: 1234,
      name: "Fruit",
      description_excerpt: "All about various kinds of fruit",
      color: "ff0",
      slug: "fruit",
    },
    {
      id: 2345,
      name: "Vegetables",
      description_excerpt: "Full of delicious vitamins",
      color: "f00",
      slug: "vegetables",
    },
    {
      id: 3456,
      name: "Beverages",
      description_excerpt: "Thirsty?",
      color: "99f",
      slug: "beverages",
      read_restricted: true,
    },
  ].map((c) => store.createRecord("category", c));

  let createUser = (attrs) => {
    userId++;

    let userData = {
      id: userId,
      username: `user_${userId}`,
      name: "John Doe",
      avatar_template: "/images/avatar.png",
      website: "discourse.com",
      website_name: "My Website is Discourse",
      location: "Toronto",
      suspend_reason: "Some reason",
      groups: [{ name: "Group 1" }, { name: "Group 2" }],
      created_at: moment().subtract(10, "days"),
      last_posted_at: moment().subtract(3, "days"),
      last_seen_at: moment().subtract(1, "days"),
      profile_view_count: 378,
      invited_by: {
        username: "user_2",
      },
      trust_level: 1,
      publicUserFields: [
        {
          field: {
            dasherized_name: "puf_1",
            name: "Public User Field 1",
          },
          value: "Some value 1",
        },
        {
          field: {
            dasherized_name: "puf_2",
            name: "Public User Field 2",
          },
          value: "Some value 2",
        },
      ],
    };

    Object.assign(userData, attrs || {});

    return store.createRecord("user", userData);
  };

  // This bg image is public domain: http://hubblesite.org/image/3999/gallery
  let user = createUser({
    profile_background: "/plugins/styleguide/images/hubble-orion-nebula-bg.jpg",
    has_profile_background: true,
  });

  let createTopic = (attrs) => {
    topicId++;
    return store.createRecord(
      "topic",
      Object.assign(
        {
          id: topicId,
          title: `Example Topic Title ${topicId}`,
          fancy_title: `Example Topic Title ${topicId}`,
          slug: `example-topic-title-${topicId}`,
          posts_count: ((topicId * 1234) % 100) + 1,
          views: ((topicId * 123) % 1000) + 1,
          like_count: topicId % 3,
          created_at: `2017-03-${topicId % 30}T12:30:00.000Z`,
          visible: true,
          posters: [
            { extras: "latest", user },
            { user: createUser() },
            { user: createUser() },
            { user: createUser() },
            { user: createUser() },
          ],
        },
        attrs || {}
      )
    );
  };

  let topic = createTopic({ tags: ["example", "apple"] });
  topic.details.updateFromJson({
    can_create_post: true,
    can_invite_to: false,
    can_delete: false,
    can_close_topic: false,
  });
  topic.setProperties({
    category_id: categories[0].id,
    suggested_topics: [topic, topic, topic],
  });

  let invisibleTopic = createTopic({ visible: false });
  let closedTopic = createTopic({ closed: true });
  closedTopic.set("category_id", categories[1].id);
  let archivedTopic = createTopic({ archived: true });
  let pinnedTopic = createTopic({ pinned: true });
  pinnedTopic.set("clearPin", () => pinnedTopic.set("pinned", "unpinned"));
  pinnedTopic.set("rePin", () => pinnedTopic.set("pinned", "pinned"));
  pinnedTopic.set("category_id", categories[2].id);
  let unpinnedTopic = createTopic({ unpinned: true });
  let warningTopic = createTopic({ is_warning: true });
  let pmTopic = createTopic({
    archetype: "private_message",
    related_messages: [topic, topic],
  });

  const bunchOfTopics = [
    topic,
    invisibleTopic,
    closedTopic,
    archivedTopic,
    pinnedTopic,
    unpinnedTopic,
    warningTopic,
  ];

  let sentence =
    "Donec viverra lacus id sapien aliquam, tempus tincidunt urna porttitor.";

  let cooked = `<p>Lorem ipsum dolor sit amet, et nec quis viderer prompta, ex omnium ponderum insolens eos, sed discere invenire principes in. Fuisset constituto per ad. Est no scripta propriae facilisis, viderer impedit deserunt in mel. Quot debet facilisis ne vix, nam in detracto tacimates. At quidam petentium vulputate pro. Alia iudico repudiandae ad vel, erat omnis epicuri eos id. Et illum dolor graeci vel, quo feugiat consulatu ei.</p>

    <p>Case everti equidem ius ea, ubique veritus vim id. Eros omnium conclusionemque qui te, usu error alienum imperdiet ut, ex ius meis adipisci. Libris reprehendunt eos ex, mea at nisl suavitate. Altera virtute democritum pro cu, melius latine in ius.</p>`;

  const excerpt =
    "<p>Lorem ipsum dolor sit amet, et nec quis viderer prompta, ex omnium ponderum insolens eos, sed discere invenire principes in. Fuisset constituto per ad. Est no scripta propriae facilisis, viderer impedit deserunt in mel. Quot debet facilisis ne vix, nam in detracto tacimates.</p>";

  const transformedPost = {
    id: 1234,
    topic,
    user: {
      avatar_template: user.avatar_template,
      id: user.id,
      username: user.username,
      name: user.name,
    },
    name: user.name,
    username: user.username,
    avatar_template: user.avatar_template,
    category: {
      id: categories[0].id,
      name: categories[0].name,
      color: categories[0].color,
    },
    created_at: "2024-11-13T21:12:37.835Z",
    cooked,
    excerpt,
    post_number: 1,
    post_type: 1,
    updated_at: moment().subtract(2, "days"),
    reply_count: 0,
    reply_to_post_number: null,
    quote_count: 0,
    incoming_link_count: 0,
    reads: 1,
    readers_count: 0,
    score: 0,
    yours: false,
    topic_id: topic.id,
    topic_slug: topic.slug,
    display_username: user.name,
    primary_group_name: null,
    flair_name: null,
    flair_url: null,
    flair_bg_color: null,
    flair_color: null,
    flair_group_id: null,
    version: 1,
    can_edit: true,
    can_delete: true,
    can_recover: true,
    can_see_hidden_post: true,
    can_wiki: true,
    read: true,
    user_title: "",
    bookmarked: false,
    actions_summary: [
      {
        id: 2,
        count: 1,
        acted: true,
        can_undo: true,
      },
      {
        id: 6,
        can_act: true,
      },
      {
        id: 3,
        can_act: true,
      },
      {
        id: 4,
        can_act: true,
      },
      {
        id: 8,
        can_act: true,
      },
      {
        id: 10,
        can_act: true,
      },
      {
        id: 7,
        can_act: true,
      },
    ],
    moderator: false,
    admin: true,
    staff: true,
    user_id: user.id,
    hidden: false,
    trust_level: user.trust_level,
    deleted_at: null,
    user_deleted: false,
    edit_reason: null,
    can_view_edit_history: true,
    wiki: false,
    activity_pub_enabled: false,
    category_expert_approved_group: null,
    needs_category_expert_approval: null,
    can_manage_category_expert_posts: false,
    reactions: [
      {
        id: "heart",
        type: "emoji",
        count: 1,
      },
    ],
    current_user_reaction: {
      id: "heart",
      type: "emoji",
      can_undo: true,
    },
    reaction_users_count: 1,
    current_user_used_main_reaction: true,
    shared_edits_enabled: null,
    can_accept_answer: false,
    can_unaccept_answer: false,
    accepted_answer: false,
    topic_accepted_answer: false,
    can_translate: false,
  };

  const postModel = store.createRecord("post", {
    transformedPost,
  });

  postModel.set("topic", store.createRecord("topic", transformedPost.topic));

  const postList = [
    transformedPost,
    {
      id: 145,
      topic: pinnedTopic,
      created_at: "2024-03-15T18:45:38.720Z",
      category: {
        id: categories[2].id,
        color: categories[2].color,
        name: categories[2].name,
      },
      user: {
        avatar_template: user.avatar_template,
        id: user.id,
        username: user.username,
        name: user.name,
      },
      excerpt,
    },
    {
      id: 144,
      topic: archivedTopic,
      created_at: "2024-02-15T18:45:38.720Z",
      category: {
        id: categories[1].id,
        color: categories[1].color,
        name: categories[1].name,
      },
      user: {
        avatar_template: user.avatar_template,
        id: user.id,
        username: user.username,
        name: user.name,
      },
      excerpt,
    },
    {
      id: 143,
      topic: closedTopic,
      created_at: "2024-01-15T18:45:38.720Z",
      category: {
        id: categories[0].id,
        color: categories[0].color,
        name: categories[0].name,
      },
      user: {
        avatar_template: user.avatar_template,
        id: user.id,
        username: user.username,
        name: user.name,
      },
      excerpt,
    },
  ];

  _data = {
    options: [
      { id: 1, name: "Orange" },
      { id: 2, name: "Blue" },
      { id: 3, name: "Red" },
      { id: 4, name: "Yellow" },
    ],

    categories,

    buttonSizes: [
      { class: "btn-large", text: "large" },
      { class: "", text: "default" },
      { class: "btn-small", text: "small" },
    ],

    buttonStates: [
      { class: "", text: "normal" },
      { class: "btn-hover", text: "hover" },
      { disabled: true, text: "disabled" },
    ],

    toggleSwitchState: true,

    navItems: ["latest", "categories", "top"].map((name) => {
      let item = NavItem.fromText(name);

      // item.set("href", "#");

      if (name === "categories") {
        item.set("styleGuideActive", true);
      }

      return item;
    }),

    topic,
    invisibleTopic,
    closedTopic,
    archivedTopic,
    pinnedTopic,
    unpinnedTopic,
    warningTopic,
    pmTopic,

    topics: bunchOfTopics,

    sentence,
    short_sentence: "Lorem ipsum dolor sit amet.",
    soon: moment().add(2, "days"),

    transformedPost,
    postModel,
    postList,

    user,

    userWithUnread: createUser({
      unread_notifications: 3,
      unread_high_priority_notifications: 7,
    }),

    lorem: cooked,
    shortLorem:
      "Lorem ipsum dolor sit amet, et nec quis viderer prompta, ex omnium ponderum insolens eos, sed discere invenire principes in. Fuisset constituto per ad. Est no scripta propriae facilisis, viderer impedit deserunt in mel. Quot debet facilisis ne vix, nam in detracto tacimates. At quidam petentium vulputate pro. Alia iudico repudiandae ad vel, erat omnis epicuri eos id. Et illum dolor graeci vel, quo feugiat consulatu ei.",

    topicTimerUpdateDate: "2017-10-18 18:00",

    groups: [
      { name: "staff", id: 1, automatic: false },
      { name: "lounge", id: 2, automatic: true },
      { name: "admin", id: 3, automatic: false },
    ],

    groupNames: ["staff", "lounge", "admin"],

    selectedGroups: [1, 2],

    settings: "bold|italic|strike|underline",

    colors: "f49|c89|564897",

    charCounterContent: "",

    selectedTags: ["apple", "orange", "potato"],
  };

  return _data;
}
