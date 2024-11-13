import transformPost from "discourse/lib/transform-post";
import NavItem from "discourse/models/nav-item";

let topicId = 2000000;
let userId = 1000000;

let _data;

export function createData(store, site) {
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

  const dummyPostData = {
    id: 1234,
    cooked,
    created_at: moment().subtract(3, "days"),
    user_id: user.id,
    username: user.username,
    avatar_template: user.avatar_template,
    post_number: 1,
    uploaded_avatar_id: 9,
    reply_count: 0,
    reply_to_post_number: null,
    quote_count: 0,
    incoming_link_count: 0,
    reads: 1,
    score: 0,
    yours: true,
    display_username: "",
    primary_group_name: null,
    version: 1,
    can_edit: true,
    can_delete: true,
    can_recover: true,
    read: true,
    user_title: null,
    actions_summary: [
      { id: 3, can_act: true },
      { id: 4, can_act: true },
      { id: 5, hidden: true, can_act: true },
      { id: 7, can_act: true },
      { id: 8, can_act: true },
    ],
    hidden: false,
    hidden_reason_id: null,
    trust_level: 4,
    deleted_at: null,
    user_deleted: false,
    edit_reason: null,
    can_view_edit_history: true,
    wiki: false,
  };

  const postModel = store.createRecord("post", {
    dummyPostData,
  });
  postModel.set("topic", store.createRecord("topic", topic));

  const transformedPost = transformPost(user, site, postModel);

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
      { class: "btn-default", text: "default" },
      { class: "btn-small", text: "small" },
    ],

    buttonStates: [
      { class: "btn-hover", text: "hover" },
      { class: "btn-active", text: "active" },
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

    topics: bunchOfTopics,

    sentence,
    short_sentence: "Lorem ipsum dolor sit amet.",
    soon: moment().add(2, "days"),

    transformedPost,
    postModel,

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
