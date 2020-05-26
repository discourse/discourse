import User from "discourse/models/user";

export function parsePostData(query) {
  const result = {};
  query.split("&").forEach(function(part) {
    const item = part.split("=");
    const firstSeg = decodeURIComponent(item[0]);
    const m = /^([^\[]+)\[(.+)\]/.exec(firstSeg);

    const val = decodeURIComponent(item[1]).replace(/\+/g, " ");
    if (m) {
      let key = m[1];
      result[key] = result[key] || {};
      result[key][m[2].replace("][", ".")] = val;
    } else {
      result[firstSeg] = val;
    }
  });
  return result;
}

export function response(code, obj) {
  if (typeof code === "object") {
    obj = code;
    code = 200;
  }
  return [code, { "Content-Type": "application/json" }, obj];
}

export function success() {
  return response({ success: true });
}

const loggedIn = () => !!User.current();
const helpers = { response, success, parsePostData };

export let fixturesByUrl;

export default new Pretender();

export function applyDefaultHandlers(pretender) {
  // Autoload any `*-pretender` files
  Object.keys(requirejs.entries).forEach(e => {
    let m = e.match(/^.*helpers\/([a-z-]+)\-pretender$/);
    if (m && m[1] !== "create") {
      let result = requirejs(e).default.call(pretender, helpers);
      if (m[1] === "fixture") {
        fixturesByUrl = result;
      }
    }
  });

  pretender.get("/admin/plugins", () => response({ plugins: [] }));

  pretender.get("/composer_messages", () =>
    response({ composer_messages: [] })
  );

  pretender.get("/latest.json", () => {
    const json = fixturesByUrl["/latest.json"];

    if (loggedIn()) {
      // Stuff to let us post
      json.topic_list.can_create_topic = true;
      json.topic_list.draft_key = "new_topic";
      json.topic_list.draft_sequence = 1;
    }
    return response(json);
  });

  pretender.get("/c/bug/1/l/latest.json", () => {
    const json = fixturesByUrl["/c/bug/1/l/latest.json"];

    if (loggedIn()) {
      // Stuff to let us post
      json.topic_list.can_create_topic = true;
      json.topic_list.draft_key = "new_topic";
      json.topic_list.draft_sequence = 1;
    }
    return response(json);
  });

  pretender.get("/tags", () => {
    return [
      200,
      { "Content-Type": "application/json" },
      {
        tags: [
          { id: "eviltrout", count: 1 },
          { id: "planned", text: "planned", count: 7, pm_count: 0 },
          { id: "private", text: "private", count: 0, pm_count: 7 }
        ],
        extras: {
          tag_groups: [
            {
              id: 2,
              name: "Ford Cars",
              tags: [
                { id: "Escort", text: "Escort", count: 1, pm_count: 0 },
                { id: "focus", text: "focus", count: 3, pm_count: 0 }
              ]
            },
            {
              id: 1,
              name: "Honda Cars",
              tags: [
                { id: "civic", text: "civic", count: 4, pm_count: 0 },
                { id: "accord", text: "accord", count: 2, pm_count: 0 }
              ]
            },
            {
              id: 1,
              name: "Makes",
              tags: [
                { id: "ford", text: "ford", count: 5, pm_count: 0 },
                { id: "honda", text: "honda", count: 6, pm_count: 0 }
              ]
            }
          ]
        }
      }
    ];
  });

  pretender.get("/tags/filter/search", () => {
    return response({ results: [{ text: "monkey", count: 1 }] });
  });

  pretender.get(`/u/:username/emails.json`, request => {
    if (request.params.username === "regular2") {
      return response({
        email: "regular2@example.com",
        secondary_emails: [
          "regular2alt1@example.com",
          "regular2alt2@example.com"
        ]
      });
    }
    return response({ email: "eviltrout@example.com" });
  });

  pretender.get("/u/eviltrout.json", () => {
    const json = fixturesByUrl["/u/eviltrout.json"];
    json.user.can_edit = loggedIn();
    return response(json);
  });

  pretender.get("/u/eviltrout/summary.json", () => {
    return response({
      user_summary: {
        topic_ids: [1234],
        replies: [{ topic_id: 1234 }],
        links: [{ topic_id: 1234, url: "https://eviltrout.com" }],
        most_replied_to_users: [{ id: 333 }],
        most_liked_by_users: [{ id: 333 }],
        most_liked_users: [{ id: 333 }],
        badges: [{ badge_id: 444 }],
        top_categories: [
          {
            id: 1,
            name: "bug",
            color: "e9dd00",
            text_color: "000000",
            slug: "bug",
            read_restricted: false,
            parent_category_id: null,
            topic_count: 1,
            post_count: 1
          }
        ]
      },
      badges: [{ id: 444, count: 1 }],
      topics: [{ id: 1234, title: "cool title", url: "/t/1234/cool-title" }]
    });
  });

  pretender.get("/u/eviltrout/invited_count.json", () => {
    return response({
      counts: { pending: 1, redeemed: 0, total: 0 }
    });
  });

  pretender.get("/u/eviltrout/invited.json", () => {
    return response({ invites: [{ id: 1 }] });
  });

  pretender.get("/topics/private-messages/eviltrout.json", () => {
    return response(fixturesByUrl["/topics/private-messages/eviltrout.json"]);
  });

  pretender.get("/topics/feature_stats.json", () => {
    return response({
      pinned_in_category_count: 0,
      pinned_globally_count: 0,
      banner_count: 0
    });
  });

  pretender.put("/t/34/convert-topic/public", () => {
    return response({});
  });

  pretender.put("/t/280/make-banner", () => {
    return response({});
  });

  pretender.put("/t/internationalization-localization/280/status", () => {
    return response({
      success: "OK",
      topic_status_update: null
    });
  });

  pretender.post("/clicks/track", success);

  pretender.get("/search", request => {
    if (request.queryParams.q === "posts") {
      return response({
        posts: [
          {
            id: 1234
          }
        ]
      });
    } else if (request.queryParams.q === "evil") {
      return response({
        posts: [
          {
            id: 1234
          }
        ],
        tags: [
          {
            id: 6,
            name: "eviltrout"
          }
        ]
      });
    }

    return response({});
  });

  pretender.put("/u/eviltrout.json", () => response({ user: {} }));

  pretender.get("/t/280.json", () => response(fixturesByUrl["/t/280/1.json"]));
  pretender.get("/t/34.json", () => response(fixturesByUrl["/t/34/1.json"]));
  pretender.get("/t/280/:post_number.json", () =>
    response(fixturesByUrl["/t/280/1.json"])
  );
  pretender.get("/t/28830.json", () =>
    response(fixturesByUrl["/t/28830/1.json"])
  );
  pretender.get("/t/9.json", () => response(fixturesByUrl["/t/9/1.json"]));
  pretender.get("/t/12.json", () => response(fixturesByUrl["/t/12/1.json"]));
  pretender.put("/t/1234/re-pin", success);

  pretender.get("/t/id_for/:slug", () => {
    return response({
      id: 280,
      slug: "internationalization-localization",
      url: "/t/internationalization-localization/280"
    });
  });

  pretender.delete("/t/:id", success);
  pretender.put("/t/:id/recover", success);
  pretender.put("/t/:id/publish", success);

  pretender.get("/permalink-check.json", () => {
    return response({
      found: false,
      html: "<div class='page-not-found'>not found</div>"
    });
  });

  pretender.delete("/draft.json", success);
  pretender.post("/draft.json", success);

  pretender.get("/u/:username/staff-info.json", () => response({}));

  pretender.get("/post_action_users", () => {
    return response({
      post_action_users: [
        {
          id: 1,
          username: "eviltrout",
          avatar_template: "/user_avatar/default/eviltrout/{size}/1.png",
          username_lower: "eviltrout"
        }
      ]
    });
  });

  pretender.get("/post_replies", () => {
    return response({ post_replies: [{ id: 1234, cooked: "wat" }] });
  });

  pretender.get("/post_reply_histories", () => {
    return response({ post_reply_histories: [{ id: 1234, cooked: "wat" }] });
  });

  pretender.get("/category_hashtags/check", () => {
    return response({ valid: [{ slug: "bug", url: "/c/bugs" }] });
  });

  pretender.get("/categories_and_latest", () =>
    response(fixturesByUrl["/categories_and_latest.json"])
  );

  pretender.put("/categories/:category_id", request => {
    const category = parsePostData(request.requestBody);
    category.id = parseInt(request.params.category_id, 10);

    if (category.email_in === "duplicate@example.com") {
      return response(422, { errors: ["duplicate email"] });
    }

    return response({ category });
  });

  pretender.get("/draft.json", request => {
    if (request.queryParams.draft_key === "new_topic") {
      return response(fixturesByUrl["/draft.json"]);
    } else if (request.queryParams.draft_key.startsWith("topic_"))
      return response(
        fixturesByUrl[request.url] || {
          draft: null,
          draft_sequence: 0
        }
      );
    return response({});
  });

  pretender.get("/drafts.json", () => response(fixturesByUrl["/drafts.json"]));

  pretender.put("/queued_posts/:queued_post_id", function(request) {
    return response({ queued_post: { id: request.params.queued_post_id } });
  });

  pretender.get("/queued_posts", function() {
    return response({
      queued_posts: [{ id: 1, raw: "queued post text", can_delete_user: true }]
    });
  });

  pretender.post("/session", function(request) {
    const data = parsePostData(request.requestBody);

    if (data.password === "correct") {
      return response({ username: "eviltrout" });
    }

    if (data.password === "not-activated") {
      return response({
        error: "not active",
        reason: "not_activated",
        sent_to_email: "<small>eviltrout@example.com</small>",
        current_email: "<small>current@example.com</small>"
      });
    }

    if (data.password === "not-activated-edit") {
      return response({
        error: "not active",
        reason: "not_activated",
        sent_to_email: "eviltrout@example.com",
        current_email: "current@example.com"
      });
    }

    if (data.password === "need-second-factor") {
      if (data.second_factor_token && data.second_factor_token === "123456") {
        return response({ username: "eviltrout" });
      }

      return response({
        failed: "FAILED",
        ok: false,
        error: "Invalid authentication code. Each code can only be used once.",
        reason: "invalid_second_factor",
        backup_enabled: true,
        security_key_enabled: false,
        totp_enabled: true,
        multiple_second_factor_methods: false
      });
    }

    if (data.password === "need-security-key") {
      if (data.securityKeyCredential) {
        return response({ username: "eviltrout" });
      }

      return response({
        failed: "FAILED",
        ok: false,
        error:
          "The selected second factor method is not enabled for your account.",
        reason: "not_enabled_second_factor_method",
        backup_enabled: false,
        security_key_enabled: true,
        totp_enabled: false,
        multiple_second_factor_methods: false,
        allowed_credential_ids: ["allowed_credential_ids"],
        challenge: "challenge"
      });
    }

    return response(400, { error: "invalid login" });
  });

  pretender.post("/u/action/send_activation_email", success);
  pretender.put("/u/update-activation-email", success);

  pretender.get("/u/hp.json", function() {
    return response({
      value: "32faff1b1ef1ac3",
      challenge: "61a3de0ccf086fb9604b76e884d75801"
    });
  });

  pretender.get("/session/csrf", function() {
    return response({ csrf: "mgk906YLagHo2gOgM1ddYjAN4hQolBdJCqlY6jYzAYs=" });
  });

  pretender.get("/groups/check-name", () => {
    return response({ available: true });
  });

  pretender.get("/u/check_username", function(request) {
    if (request.queryParams.username === "taken") {
      return response({ available: false, suggestion: "nottaken" });
    }
    return response({ available: true });
  });

  pretender.post("/u", () => response({ success: true }));

  pretender.get("/login.html", () => [200, {}, "LOGIN PAGE"]);

  pretender.delete("/posts/:post_id", success);
  pretender.put("/posts/:post_id/recover", success);
  pretender.get("/posts/:post_id/expand-embed", success);

  pretender.put("/posts/:post_id", request => {
    const data = parsePostData(request.requestBody);
    if (data.post.raw === "this will 409") {
      return [
        409,
        { "Content-Type": "application/json" },
        { errors: ["edit conflict"] }
      ];
    }
    data.post.id = request.params.post_id;
    data.post.version = 2;
    return response(200, data.post);
  });

  pretender.get("/t/403.json", () => response(403, {}));
  pretender.get("/t/404.json", () => response(404, "not found"));
  pretender.get("/t/500.json", () => response(502, {}));

  pretender.put("/t/:slug/:id", request => {
    const isJSON = request.requestHeaders["Content-Type"].includes(
      "application/json"
    );

    const data = isJSON
      ? JSON.parse(request.requestBody)
      : parsePostData(request.requestBody);

    return response(200, {
      basic_topic: {
        id: request.params.id,
        title: data.title,
        fancy_title: data.title,
        slug: request.params.slug
      }
    });
  });

  pretender.get("groups", () => {
    return response(200, fixturesByUrl["/groups.json"]);
  });

  pretender.get("/groups.json", () => {
    return response(200, fixturesByUrl["/groups.json?username=eviltrout"]);
  });

  pretender.get("groups/search.json", () => {
    return response(200, []);
  });

  pretender.get("/topics/groups/discourse.json", () => {
    return response(200, fixturesByUrl["/topics/groups/discourse.json"]);
  });

  pretender.get("/groups/discourse/mentions.json", () => {
    return response(200, fixturesByUrl["/groups/discourse/posts.json"]);
  });

  pretender.get("/groups/discourse/messages.json", () => {
    return response(200, fixturesByUrl["/groups/discourse/posts.json"]);
  });

  pretender.get("/groups/moderators/members.json", () => {
    return response(200, fixturesByUrl["/groups/discourse/members.json"]);
  });

  pretender.get("/t/:topic_id/posts.json", request => {
    const postIds = request.queryParams.post_ids;
    const postNumber = parseInt(request.queryParams.post_number, 10);
    let posts;

    if (postIds) {
      posts = postIds.map(p => ({
        id: parseInt(p, 10),
        post_number: parseInt(p, 10)
      }));
    } else if (postNumber && request.queryParams.asc === "true") {
      posts = _.range(postNumber + 1, postNumber + 6).map(p => ({
        id: parseInt(p, 10),
        post_number: parseInt(p, 10)
      }));
    } else if (postNumber && request.queryParams.asc === "false") {
      posts = _.range(postNumber - 5, postNumber)
        .reverse()
        .map(p => ({
          id: parseInt(p, 10),
          post_number: parseInt(p, 10)
        }));
    }

    return response(200, { post_stream: { posts } });
  });

  pretender.get("/posts/:post_id/reply-history.json", () => {
    return response(200, [{ id: 2222, post_number: 2222 }]);
  });

  pretender.get("/posts/:post_id/reply-ids.json", () => {
    return response(200, {
      direct_reply_ids: [45],
      all_reply_ids: [45, 100]
    });
  });

  pretender.post("/user_badges", () =>
    response(200, fixturesByUrl["/user_badges"])
  );
  pretender.delete("/user_badges/:badge_id", success);

  pretender.post("/posts", function(request) {
    const data = parsePostData(request.requestBody);

    if (data.title === "this title triggers an error") {
      return response(422, { errors: ["That title has already been taken"] });
    }

    if (data.raw === "enqueue this content please") {
      return response(200, {
        success: true,
        action: "enqueued",
        pending_post: {
          id: 1234,
          raw: data.raw
        }
      });
    }

    if (data.raw === "custom message") {
      return response(200, {
        success: true,
        action: "custom",
        message: "This is a custom response",
        route_to: "/faq"
      });
    }

    return response(200, {
      success: true,
      action: "create_post",
      post: {
        id: 12345,
        topic_id: 280,
        topic_slug: "internationalization-localization"
      }
    });
  });

  pretender.post("/topics/timings", () => response(200, {}));

  const siteText = { id: "site.test", value: "Test McTest" };
  const overridden = {
    id: "site.overridden",
    value: "Overridden",
    overridden: true
  };

  pretender.get("/admin/users/list/active.json", request => {
    let store = [
      {
        id: 1,
        username: "eviltrout",
        email: "<small>eviltrout@example.com</small>"
      },
      {
        id: 3,
        username: "discobot",
        email: "<small>discobot_email</small>"
      }
    ];

    const showEmails = request.queryParams.show_emails;

    if (showEmails === "false") {
      store = store.map(item => {
        delete item.email;
        return item;
      });
    }

    const asc = request.queryParams.asc;
    const order = request.queryParams.order;

    if (order) {
      store = store.sort(function(a, b) {
        return a[order] - b[order];
      });
    }

    if (asc) {
      store = store.reverse();
    }

    return response(200, store);
  });

  pretender.get("/admin/users/list/new.json", () => {
    return response(200, [
      {
        id: 2,
        username: "sam",
        email: "<small>sam@example.com</small>"
      }
    ]);
  });

  pretender.get("/admin/customize/site_texts", request => {
    if (request.queryParams.overridden) {
      return response(200, { site_texts: [overridden] });
    } else {
      return response(200, { site_texts: [siteText, overridden] });
    }
  });

  pretender.get("/admin/customize/site_texts/:key", () =>
    response(200, { site_text: siteText })
  );
  pretender.delete("/admin/customize/site_texts/:key", () =>
    response(200, { site_text: siteText })
  );

  pretender.put("/admin/customize/site_texts/:key", request => {
    const result = parsePostData(request.requestBody);
    result.id = request.params.key;
    result.can_revert = true;
    return response(200, { site_text: result });
  });

  pretender.get("/tag_groups", () => response(200, { tag_groups: [] }));

  pretender.get("/admin/users/1.json", () => {
    return response(200, {
      id: 1,
      username: "eviltrout",
      email: "eviltrout@example.com",
      admin: true
    });
  });

  pretender.get("/admin/users/2.json", () => {
    return response(200, {
      id: 2,
      username: "sam",
      admin: true
    });
  });

  pretender.get("/admin/users/3.json", () => {
    return response(200, {
      id: 3,
      username: "markvanlan",
      email: "markvanlan@example.com",
      secondary_emails: ["markvanlan1@example.com", "markvanlan2@example.com"]
    });
  });

  pretender.get("/admin/users/1234.json", () => {
    return response(200, {
      id: 1234,
      username: "regular"
    });
  });

  pretender.get("/admin/users/1235.json", () => {
    return response(200, {
      id: 1235,
      username: "regular2"
    });
  });

  pretender.delete("/admin/users/:user_id.json", () =>
    response(200, { deleted: true })
  );
  pretender.post("/admin/badges", success);
  pretender.delete("/admin/badges/:id", success);

  pretender.get("/admin/logs/staff_action_logs.json", () => {
    return response(200, {
      staff_action_logs: [],
      extras: { user_history_actions: [] }
    });
  });

  pretender.get("/admin/logs/watched_words", () => {
    return response(200, fixturesByUrl["/admin/logs/watched_words.json"]);
  });
  pretender.delete("/admin/logs/watched_words/:id.json", success);

  pretender.post("/admin/logs/watched_words.json", request => {
    const result = parsePostData(request.requestBody);
    result.id = new Date().getTime();
    return response(200, result);
  });

  pretender.get("/admin/logs/search_logs.json", () => {
    return response(200, [
      { term: "foobar", searches: 35, click_through: 6, unique: 16 }
    ]);
  });

  pretender.get("/admin/logs/search_logs/term.json", () => {
    return response(200, {
      term: {
        type: "search_log_term",
        title: "Search Count",
        term: "ruby",
        data: [{ x: "2017-07-20", y: 2 }]
      }
    });
  });

  pretender.post("/uploads/lookup-metadata", () => {
    return response(200, {
      imageFilename: "somefile.png",
      imageFilesize: "10 KB",
      imageWidth: "1",
      imageHeight: "1"
    });
  });

  pretender.get("/inline-onebox", request => {
    if (
      request.queryParams.urls.includes("http://www.example.com/has-title.html")
    ) {
      return [
        200,
        { "Content-Type": "application/html" },
        '{"inline-oneboxes":[{"url":"http://www.example.com/has-title.html","title":"This is a great title"}]}'
      ];
    }
  });

  pretender.get("/onebox", request => {
    if (
      request.queryParams.url === "http://www.example.com/has-title.html" ||
      request.queryParams.url ===
        "http://www.example.com/has-title-and-a-url-that-is-more-than-80-characters-because-thats-good-for-seo-i-guess.html"
    ) {
      return [
        200,
        { "Content-Type": "application/html" },
        '<aside class="onebox"><article class="onebox-body"><h3><a href="http://www.example.com/article.html">An interesting article</a></h3></article></aside>'
      ];
    }

    if (request.queryParams.url === "http://www.example.com/no-title.html") {
      return [
        200,
        { "Content-Type": "application/html" },
        '<aside class="onebox"><article class="onebox-body"><p>No title</p></article></aside>'
      ];
    }

    if (request.queryParams.url.indexOf("/internal-page.html") > -1) {
      return [
        200,
        { "Content-Type": "application/html" },
        '<aside class="onebox"><article class="onebox-body"><h3><a href="/internal-page.html">Internal Page 4 U</a></h3></article></aside>'
      ];
    }
    if (request.queryParams.url === "http://somegoodurl.com/") {
      return [
        200,
        { "Content-Type": "application/html" },
        `
    <aside class="onebox whitelistedgeneric">
      <header class="source">
          <a href="http://test.com/somepage" target="_blank">test.com</a>
      </header>
      <article class="onebox-body">
      <div class="aspect-image" style="--aspect-ratio:690/362;"><img src="https://test.com/image.png" class="thumbnail"></div>
      <h3><a href="http://test.com/somepage" target="_blank">Test Page</a></h3>
      <p>Yet another collaboration tool</p>
      </article>
      <div class="onebox-metadata"></div>
      <div style="clear: both"></div>
    </aside>
  `
      ];
    }
    return [404, { "Content-Type": "application/html" }, ""];
  });
}
