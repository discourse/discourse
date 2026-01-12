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
    displayDate: moment().subtract(3, "days"),
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

  // Onebox post examples
  const wikipediaOneboxCooked = `<p>Check out this Wikipedia article:</p>
<aside class="onebox allowlistedgeneric" data-onebox-src="https://en.wikipedia.org/wiki/Discourse_(software)">
  <header class="source">
    <img src="https://en.wikipedia.org/static/favicon/wikipedia.ico" class="site-icon" width="16" height="16" />
    <a href="https://en.wikipedia.org/wiki/Discourse_(software)" target="_blank" rel="noopener">en.wikipedia.org</a>
  </header>
  <article class="onebox-body">
    <img src="/plugins/styleguide/images/hubble-orion-nebula-bg.jpg" class="thumbnail" width="200" height="200" />
    <h3><a href="https://en.wikipedia.org/wiki/Discourse_(software)" target="_blank" rel="noopener">Discourse (software)</a></h3>
    <p>Discourse is an open source Internet forum and mailing list management software application founded in 2013 by Jeff Atwood, Robin Ward, and Sam Saffron.</p>
  </article>
</aside>`;

  const githubPrOpenCooked = `<p>Here's the PR I mentioned:</p>
<aside class="onebox githubpullrequest" data-onebox-src="https://github.com/discourse/discourse/pull/1234">
  <header class="source">
    <a href="https://github.com/discourse/discourse/pull/1234" target="_blank" rel="noopener">github.com/discourse/discourse</a>
  </header>
  <article class="onebox-body">
    <div class="github-row --gh-status-open">
      <div class="github-icon-container" title="Open">
        <svg width="60" height="60" class="github-icon" viewBox="0 0 12 16" aria-hidden="true"><path fill-rule="evenodd" d="M11 11.28V5c-.03-.78-.34-1.47-.94-2.06C9.46 2.35 8.78 2.03 8 2H7V0L4 3l3 3V4h1c.27.02.48.11.69.31.21.2.3.42.31.69v6.28A1.993 1.993 0 0 0 10 15a1.993 1.993 0 0 0 1-3.72zm-1 2.92c-.66 0-1.2-.55-1.2-1.2 0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2 0 .65-.55 1.2-1.2 1.2zM4 3c0-1.11-.89-2-2-2a1.993 1.993 0 0 0-1 3.72v6.56A1.993 1.993 0 0 0 2 15a1.993 1.993 0 0 0 1-3.72V4.72c.59-.34 1-.98 1-1.72zm-.8 10c0 .66-.55 1.2-1.2 1.2-.65 0-1.2-.55-1.2-1.2 0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2zM2 4.2C1.34 4.2.8 3.65.8 3c0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2 0 .65-.55 1.2-1.2 1.2z"></path></svg>
      </div>
      <div class="github-info-container">
        <h4><a href="https://github.com/discourse/discourse/pull/1234" target="_blank" rel="noopener">FIX: Improve loading state for topic lists</a></h4>
        <div class="branches"><code>discourse:main</code> ← <code>username:fix-loading-state</code></div>
        <div class="github-info">
          <div class="date"><span class="status-label">opened Jan 5, 2026</div>
          <div class="user"><img alt="" src="/images/avatar.png" class="onebox-avatar-inline" width="20" height="20" /> username</div>
          <div class="lines"><span class="added">+42</span> <span class="removed">-15</span></div>
        </div>
      </div>
    </div>
  </article>
</aside>`;

  const githubPrApprovedCooked = `<p>This one is ready to merge:</p>
<aside class="onebox githubpullrequest" data-onebox-src="https://github.com/discourse/discourse/pull/1235">
  <header class="source">
    <a href="https://github.com/discourse/discourse/pull/1235" target="_blank" rel="noopener">github.com/discourse/discourse</a>
  </header>
  <article class="onebox-body">
    <div class="github-row --gh-status-approved">
      <div class="github-icon-container" title="Approved">
        <svg width="60" height="60" class="github-icon" viewBox="0 0 12 16" aria-hidden="true"><path fill-rule="evenodd" d="M11 11.28V5c-.03-.78-.34-1.47-.94-2.06C9.46 2.35 8.78 2.03 8 2H7V0L4 3l3 3V4h1c.27.02.48.11.69.31.21.2.3.42.31.69v6.28A1.993 1.993 0 0 0 10 15a1.993 1.993 0 0 0 1-3.72zm-1 2.92c-.66 0-1.2-.55-1.2-1.2 0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2 0 .65-.55 1.2-1.2 1.2zM4 3c0-1.11-.89-2-2-2a1.993 1.993 0 0 0-1 3.72v6.56A1.993 1.993 0 0 0 2 15a1.993 1.993 0 0 0 1-3.72V4.72c.59-.34 1-.98 1-1.72zm-.8 10c0 .66-.55 1.2-1.2 1.2-.65 0-1.2-.55-1.2-1.2 0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2zM2 4.2C1.34 4.2.8 3.65.8 3c0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2 0 .65-.55 1.2-1.2 1.2z"></path></svg>
      </div>
      <div class="github-info-container">
        <h4><a href="https://github.com/discourse/discourse/pull/1235" target="_blank" rel="noopener">FEATURE: Add dark mode support for composer</a></h4>
        <div class="branches"><code>discourse:main</code> ← <code>contributor:dark-mode-composer</code></div>
        <div class="github-info">
          <div class="date">approved Jan 4, 2026</div>
          <div class="user"><img alt="" src="/images/avatar.png" class="onebox-avatar-inline" width="20" height="20" /> contributor</div>
          <div class="lines"><span class="added">+156</span> <span class="removed">-23</span></div>
        </div>
      </div>
    </div>
  </article>
</aside>`;

  const githubPrChangesRequestedCooked = `<p>Needs some changes:</p>
<aside class="onebox githubpullrequest" data-onebox-src="https://github.com/discourse/discourse/pull/1236">
  <header class="source">
    <a href="https://github.com/discourse/discourse/pull/1236" target="_blank" rel="noopener">github.com/discourse/discourse</a>
  </header>
  <article class="onebox-body">
    <div class="github-row --gh-status-changes_requested">
      <div class="github-icon-container" title="Changes Requested">
        <svg width="60" height="60" class="github-icon" viewBox="0 0 12 16" aria-hidden="true"><path fill-rule="evenodd" d="M11 11.28V5c-.03-.78-.34-1.47-.94-2.06C9.46 2.35 8.78 2.03 8 2H7V0L4 3l3 3V4h1c.27.02.48.11.69.31.21.2.3.42.31.69v6.28A1.993 1.993 0 0 0 10 15a1.993 1.993 0 0 0 1-3.72zm-1 2.92c-.66 0-1.2-.55-1.2-1.2 0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2 0 .65-.55 1.2-1.2 1.2zM4 3c0-1.11-.89-2-2-2a1.993 1.993 0 0 0-1 3.72v6.56A1.993 1.993 0 0 0 2 15a1.993 1.993 0 0 0 1-3.72V4.72c.59-.34 1-.98 1-1.72zm-.8 10c0 .66-.55 1.2-1.2 1.2-.65 0-1.2-.55-1.2-1.2 0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2zM2 4.2C1.34 4.2.8 3.65.8 3c0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2 0 .65-.55 1.2-1.2 1.2z"></path></svg>
      </div>
      <div class="github-info-container">
        <h4><a href="https://github.com/discourse/discourse/pull/1236" target="_blank" rel="noopener">DEV: Refactor user preferences controller</a></h4>
        <div class="branches"><code>discourse:main</code> ← <code>developer:refactor-prefs</code></div>
        <div class="github-info">
          <div class="date">changes requested Jan 3, 2026</div>
          <div class="user"><img alt="" src="/images/avatar.png" class="onebox-avatar-inline" width="20" height="20" /> developer</div>
          <div class="lines"><span class="added">+89</span> <span class="removed">-234</span></div>
        </div>
      </div>
    </div>
  </article>
</aside>`;

  const githubPrMergedCooked = `<p>This was merged yesterday:</p>
<aside class="onebox githubpullrequest" data-onebox-src="https://github.com/discourse/discourse/pull/1237">
  <header class="source">
    <a href="https://github.com/discourse/discourse/pull/1237" target="_blank" rel="noopener">github.com/discourse/discourse</a>
  </header>
  <article class="onebox-body">
    <div class="github-row --gh-status-merged">
      <div class="github-icon-container" title="Merged">
        <svg width="60" height="60" class="github-icon" viewBox="0 0 12 16" aria-hidden="true"><path fill-rule="evenodd" d="M11 11.28V5c-.03-.78-.34-1.47-.94-2.06C9.46 2.35 8.78 2.03 8 2H7V0L4 3l3 3V4h1c.27.02.48.11.69.31.21.2.3.42.31.69v6.28A1.993 1.993 0 0 0 10 15a1.993 1.993 0 0 0 1-3.72zm-1 2.92c-.66 0-1.2-.55-1.2-1.2 0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2 0 .65-.55 1.2-1.2 1.2zM4 3c0-1.11-.89-2-2-2a1.993 1.993 0 0 0-1 3.72v6.56A1.993 1.993 0 0 0 2 15a1.993 1.993 0 0 0 1-3.72V4.72c.59-.34 1-.98 1-1.72zm-.8 10c0 .66-.55 1.2-1.2 1.2-.65 0-1.2-.55-1.2-1.2 0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2zM2 4.2C1.34 4.2.8 3.65.8 3c0-.65.55-1.2 1.2-1.2.65 0 1.2.55 1.2 1.2 0 .65-.55 1.2-1.2 1.2z"></path></svg>
      </div>
      <div class="github-info-container">
        <h4><a href="https://github.com/discourse/discourse/pull/1237" target="_blank" rel="noopener">SECURITY: Sanitize user input in search queries</a></h4>
        <div class="branches"><code>discourse:main</code> ← <code>security-team:sanitize-search</code></div>
        <div class="github-info">
          <div class="date">merged Jan 2, 2026</div>
          <div class="user"><img alt="" src="/images/avatar.png" class="onebox-avatar-inline" width="20" height="20" /> security-team</div>
          <div class="lines"><span class="added">+12</span> <span class="removed">-5</span></div>
        </div>
      </div>
    </div>
  </article>
</aside>`;

  const createOneboxPost = (id, cookedContent) => ({
    id,
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
    created_at: "2024-11-13T21:12:37.835Z",
    displayDate: moment().subtract(3, "days"),
    cooked: cookedContent,
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
    version: 1,
    can_edit: true,
    can_delete: true,
    can_recover: true,
    can_see_hidden_post: true,
    can_wiki: true,
    read: true,
    user_title: "",
    bookmarked: false,
    actions_summary: [],
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
  });

  const oneboxPosts = {
    wikipedia: createOneboxPost(2001, wikipediaOneboxCooked),
    githubPrOpen: createOneboxPost(2002, githubPrOpenCooked),
    githubPrApproved: createOneboxPost(2003, githubPrApprovedCooked),
    githubPrChangesRequested: createOneboxPost(
      2004,
      githubPrChangesRequestedCooked
    ),
    githubPrMerged: createOneboxPost(2005, githubPrMergedCooked),
  };

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
    oneboxPosts,

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
