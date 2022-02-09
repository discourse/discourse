import Pretender from "pretender";
import User from "discourse/models/user";
import getURL from "discourse-common/lib/get-url";
import { Promise } from "rsvp";

export function parsePostData(query) {
  const result = {};
  if (query) {
    query.split("&").forEach(function (part) {
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
  }
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

const instance = new Pretender();

const oldRegister = instance.register;
instance.register = (...args) => {
  args[1] = getURL(args[1]);
  return oldRegister.call(instance, ...args);
};

export default instance;

export function pretenderHelpers() {
  return { parsePostData, response, success };
}

export function applyDefaultHandlers(pretender) {
  // Autoload any `*-pretender` files
  Object.keys(requirejs.entries).forEach((e) => {
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
    }
    return response(json);
  });

  pretender.get("/c/bug/1/l/latest.json", () => {
    const json = fixturesByUrl["/c/bug/1/l/latest.json"];

    if (loggedIn()) {
      // Stuff to let us post
      json.topic_list.can_create_topic = true;
    }
    return response(json);
  });

  pretender.get("/tags", () => {
    return response({
      tags: [
        { id: "eviltrout", count: 1 },
        { id: "planned", text: "planned", count: 7, pm_count: 0 },
        { id: "private", text: "private", count: 0, pm_count: 7 },
      ],
      extras: {
        tag_groups: [
          {
            id: 2,
            name: "Ford Cars",
            tags: [
              { id: "Escort", text: "Escort", count: 1, pm_count: 0 },
              { id: "focus", text: "focus", count: 3, pm_count: 0 },
            ],
          },
          {
            id: 1,
            name: "Honda Cars",
            tags: [
              { id: "civic", text: "civic", count: 4, pm_count: 0 },
              { id: "accord", text: "accord", count: 2, pm_count: 0 },
            ],
          },
          {
            id: 1,
            name: "Makes",
            tags: [
              { id: "ford", text: "ford", count: 5, pm_count: 0 },
              { id: "honda", text: "honda", count: 6, pm_count: 0 },
            ],
          },
        ],
      },
    });
  });

  pretender.delete("/bookmarks/:id", () => response({}));

  pretender.get("/tags/filter/search", () => {
    return response({
      results: [
        { id: "monkey", name: "monkey", count: 1 },
        { id: "gazelle", name: "gazelle", count: 2 },
      ],
    });
  });

  pretender.get(`/u/:username/emails.json`, (request) => {
    if (request.params.username === "regular2") {
      return response({
        email: "regular2@example.com",
        secondary_emails: [
          "regular2alt1@example.com",
          "regular2alt2@example.com",
        ],
      });
    }
    return response({ email: "eviltrout@example.com" });
  });

  pretender.get("/u/is_local_username", () =>
    response({
      valid: [],
      valid_groups: [],
      mentionable_groups: [],
      cannot_see: [],
    })
  );

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
            post_count: 1,
          },
        ],
      },
      badges: [{ id: 444, count: 1 }],
      topics: [{ id: 1234, title: "cool title", slug: "cool-title" }],
    });
  });

  pretender.get("/u/eviltrout/invited.json", () => {
    return response({
      invites: [],
      can_see_invite_details: true,
      counts: {
        pending: 0,
        expired: 0,
        redeemed: 0,
        total: 0,
      },
    });
  });

  [
    "/topics/private-messages-all/:username.json",
    "/topics/private-messages/:username.json",
    "/topics/private-messages-warnings/eviltrout.json",
  ].forEach((url) => {
    pretender.get(url, () => {
      return response(fixturesByUrl["/topics/private-messages/eviltrout.json"]);
    });
  });

  pretender.get("/u/:username/private-message-topic-tracking-state", () => {
    return response([]);
  });

  pretender.get("/topics/feature_stats.json", () => {
    return response({
      pinned_in_category_count: 0,
      pinned_globally_count: 0,
      banner_count: 0,
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
      topic_status_update: null,
    });
  });

  pretender.post("/clicks/track", success);

  pretender.get("/search", (request) => {
    if (request.queryParams.q === "discourse") {
      return response(fixturesByUrl["/search.json"]);
    } else if (request.queryParams.q === "discourse in:personal") {
      const fixtures = fixturesByUrl["/search.json"];
      fixtures.topics.firstObject.archetype = "private_message";
      return response(fixtures);
    } else {
      return response({});
    }
  });

  pretender.put("/u/eviltrout.json", () => response({ user: {} }));

  pretender.get("/t/280.json", () => response(fixturesByUrl["/t/280/1.json"]));
  pretender.get("/t/34.json", () => response(fixturesByUrl["/t/34/1.json"]));
  pretender.get("/t/34/4.json", () => response(fixturesByUrl["/t/34/1.json"]));
  pretender.get("/t/280/:post_number.json", () =>
    response(fixturesByUrl["/t/280/1.json"])
  );
  pretender.get("/t/28830.json", () =>
    response(fixturesByUrl["/t/28830/1.json"])
  );
  pretender.get("/t/9.json", () => response(fixturesByUrl["/t/9/1.json"]));
  pretender.get("/t/12.json", () => response(fixturesByUrl["/t/12/1.json"]));
  pretender.put("/t/1234/re-pin", success);

  pretender.get("/t/2480.json", () =>
    response(fixturesByUrl["/t/2480/1.json"])
  );
  pretender.get("/t/2481.json", () =>
    response(fixturesByUrl["/t/2481/1.json"])
  );

  pretender.get("/t/id_for/:slug", () => {
    return response({
      topic_id: 280,
      slug: "internationalization-localization",
      url: "/t/internationalization-localization/280",
    });
  });

  pretender.delete("/t/:id", success);
  pretender.put("/t/:id/recover", success);
  pretender.put("/t/:id/publish", success);

  pretender.get("/permalink-check.json", () => response({ found: false }));

  pretender.delete("/drafts/:draft_key.json", success);
  pretender.post("/drafts.json", success);

  pretender.get("/u/:username/staff-info.json", () => response({}));

  pretender.get("/post_action_users", () => {
    return response({
      post_action_users: [
        {
          id: 1,
          username: "eviltrout",
          avatar_template: "/user_avatar/default/eviltrout/{size}/1.png",
          username_lower: "eviltrout",
        },
      ],
    });
  });

  // TODO: Remove this old path when no longer using old ember
  pretender.get("/post_replies", () => {
    return response({ post_replies: [{ id: 1234, cooked: "wat" }] });
  });

  pretender.get("/posts/:id/replies", () => {
    return response([{ id: 1234, cooked: "wat" }]);
  });

  // TODO: Remove this old path when no longer using old ember
  pretender.get("/post_reply_histories", () => {
    return response({ post_reply_histories: [{ id: 1234, cooked: "wat" }] });
  });

  pretender.get("/posts/:id/reply-history", () => {
    return response([{ id: 1234, cooked: "wat" }]);
  });

  pretender.get("/categories_and_latest", () =>
    response(fixturesByUrl["/categories_and_latest.json"])
  );

  pretender.get("/c/bug/find_by_slug.json", () =>
    response(fixturesByUrl["/c/1/show.json"])
  );

  pretender.get("/c/1-category/find_by_slug.json", () =>
    response(fixturesByUrl["/c/1/show.json"])
  );

  pretender.get("/c/restricted-group/find_by_slug.json", () =>
    response(fixturesByUrl["/c/2481/show.json"])
  );

  pretender.put("/categories/:category_id", (request) => {
    const category = parsePostData(request.requestBody);
    category.id = parseInt(request.params.category_id, 10);

    if (category.email_in === "duplicate@example.com") {
      return response(422, { errors: ["duplicate email"] });
    }

    return response({ category });
  });

  pretender.post("/categories", () =>
    response(fixturesByUrl["/c/11/show.json"])
  );

  pretender.get("/c/testing/find_by_slug.json", () =>
    response(fixturesByUrl["/c/11/show.json"])
  );

  pretender.get("/drafts.json", () => response(fixturesByUrl["/drafts.json"]));

  pretender.get("/drafts/:draft_key.json", (request) =>
    response(fixturesByUrl[request.url] || { draft: null, draft_sequence: 0 })
  );

  pretender.get("/drafts.json", () => response(fixturesByUrl["/drafts.json"]));

  pretender.put("/queued_posts/:queued_post_id", function (request) {
    return response({ queued_post: { id: request.params.queued_post_id } });
  });

  pretender.get("/queued_posts", function () {
    return response({
      queued_posts: [{ id: 1, raw: "queued post text", can_delete_user: true }],
    });
  });

  pretender.post("/session", function (request) {
    const data = parsePostData(request.requestBody);

    if (data.password === "correct") {
      return response({ username: "eviltrout" });
    }

    if (data.password === "not-activated") {
      return response({
        error: "not active",
        reason: "not_activated",
        sent_to_email: "<small>eviltrout@example.com</small>",
        current_email: "<small>current@example.com</small>",
      });
    }

    if (data.password === "not-activated-edit") {
      return response({
        error: "not active",
        reason: "not_activated",
        sent_to_email: "eviltrout@example.com",
        current_email: "current@example.com",
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
        multiple_second_factor_methods: false,
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
        challenge: "challenge",
      });
    }

    return response(400, { error: "invalid login" });
  });

  pretender.post("/u/action/send_activation_email", success);
  pretender.put("/u/update-activation-email", success);

  pretender.get("/session/hp.json", function () {
    return response({
      value: "32faff1b1ef1ac3",
      challenge: "61a3de0ccf086fb9604b76e884d75801",
    });
  });

  pretender.get("/session/csrf", function () {
    return response({ csrf: "mgk906YLagHo2gOgM1ddYjAN4hQolBdJCqlY6jYzAYs=" });
  });

  pretender.get("/groups/check-name", () => {
    return response({ available: true });
  });

  pretender.get("/u/check_username", function (request) {
    if (request.queryParams.username === "taken") {
      return response({ available: false, suggestion: "nottaken" });
    }
    return response({ available: true });
  });

  pretender.get("/u/check_email", function () {
    return response({ success: "OK" });
  });

  pretender.post("/u", () => response({ success: true }));

  pretender.get("/login.html", () => [200, {}, "LOGIN PAGE"]);

  pretender.delete("/posts/:post_id", success);
  pretender.put("/posts/:post_id/recover", success);
  pretender.get("/posts/:post_id/expand-embed", success);

  pretender.put("/posts/:post_id", async (request) => {
    const data = parsePostData(request.requestBody);
    if (data.post.raw === "this will 409") {
      return response(409, { errors: ["edit conflict"] });
    } else if (data.post.raw === "will return empty json") {
      window.resolveLastPromise();
      return new Promise((resolve) => {
        window.resolveLastPromise = resolve;
      }).then(() => response(200, {}));
    }
    data.post.id = request.params.post_id;
    data.post.version = 2;
    return response(200, data.post);
  });

  pretender.get("/t/403.json", () => response(403, {}));
  pretender.get("/t/404.json", () => response(404, "not found"));
  pretender.get("/t/500.json", () => response(502, {}));

  pretender.put("/t/:slug/:id", (request) => {
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
        slug: request.params.slug,
      },
    });
  });

  pretender.get("/groups", () => {
    return response(200, fixturesByUrl["/groups.json"]);
  });

  pretender.get("/groups.json", () => {
    return response(200, fixturesByUrl["/groups.json?username=eviltrout"]);
  });

  pretender.get("/groups/search.json", () => {
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

  pretender.get("/t/:topic_id/posts.json", (request) => {
    const postIds = request.queryParams.post_ids;
    const postNumber = parseInt(request.queryParams.post_number, 10);
    let posts;

    if (postIds) {
      posts = postIds.map((p) => ({
        id: parseInt(p, 10),
        post_number: parseInt(p, 10),
      }));
    } else if (postNumber && request.queryParams.asc === "true") {
      posts = [...Array(5).keys()].map((p) => ({
        id: p + postNumber + 1,
        post_number: p + postNumber + 1,
      }));
    } else if (postNumber && request.queryParams.asc === "false") {
      posts = [...Array(5).keys()].map((p) => ({
        id: postNumber - p - 1,
        post_number: postNumber - p - 1,
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
      all_reply_ids: [45, 100],
    });
  });

  pretender.post("/user_badges", () =>
    response(200, fixturesByUrl["/user_badges"])
  );
  pretender.delete("/user_badges/:badge_id", success);
  pretender.put("/user_badges/:id/toggle_favorite", () =>
    response(200, { user_badge: { is_favorite: true } })
  );

  pretender.post("/posts", function (request) {
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
          raw: data.raw,
        },
      });
    }

    if (data.raw === "custom message") {
      return response(200, {
        success: true,
        action: "custom",
        message: "This is a custom response",
        route_to: "/faq",
      });
    }

    return response(200, {
      success: true,
      action: "create_post",
      post: {
        id: 12345,
        topic_id: 280,
        topic_slug: "internationalization-localization",
      },
    });
  });

  pretender.post("/topics/timings", () => response(200, {}));

  const siteText = { id: "site.test", value: "Test McTest" };
  const overridden = {
    id: "site.overridden",
    value: "Overridden",
    overridden: true,
  };

  pretender.get("/admin/users/list/active.json", (request) => {
    let store = [
      {
        id: 1,
        username: "eviltrout",
        email: "<small>eviltrout@example.com</small>",
      },
      {
        id: 3,
        username: "discobot",
        email: "<small>discobot_email</small>",
      },
    ];

    const showEmails = request.queryParams.show_emails;

    if (showEmails === "false") {
      store = store.map((item) => {
        delete item.email;
        return item;
      });
    }

    const asc = request.queryParams.asc;
    const order = request.queryParams.order;

    if (order) {
      store = store.sort(function (a, b) {
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
        email: "<small>sam@example.com</small>",
      },
    ]);
  });

  pretender.get("/admin/customize/site_texts", (request) => {
    if (request.queryParams.overridden) {
      return response(200, {
        site_texts: [overridden],
        extras: { locale: "en" },
      });
    } else {
      return response(200, {
        site_texts: [siteText, overridden],
        extras: { locale: "en" },
      });
    }
  });

  pretender.get("/admin/customize/site_texts/:key", () =>
    response(200, { site_text: siteText })
  );
  pretender.delete("/admin/customize/site_texts/:key", () =>
    response(200, { site_text: siteText })
  );

  pretender.put("/admin/customize/site_texts/:key", (request) => {
    const result = parsePostData(request.requestBody);
    result.id = request.params.key;
    result.can_revert = true;
    return response(200, { site_text: result });
  });

  pretender.get("/admin/themes", () => {
    return response(200, {
      themes: [
        {
          id: 1,
          name: "Graceful Renamed",
          remote_theme: {
            remote_url: "https://github.com/discourse/graceful.git",
          },
        },
      ],
      extras: {},
    });
  });

  pretender.post("/admin/themes/generate_key_pair", () => {
    return response(200, {
      private_key: "privateKey",
      public_key: "publicKey",
    });
  });

  pretender.get("/tag_groups", () => response(200, { tag_groups: [] }));

  pretender.get("/admin/users/1.json", () => {
    return response(200, {
      id: 1,
      username: "eviltrout",
      email: "eviltrout@example.com",
      admin: true,
      post_edits_count: 6,
    });
  });

  pretender.get("/admin/users/2.json", () => {
    return response(200, {
      id: 2,
      username: "sam",
      admin: true,
    });
  });

  pretender.get("/admin/users/3.json", () => {
    return response(200, {
      id: 3,
      username: "markvanlan",
      email: "markvanlan@example.com",
      secondary_emails: ["markvanlan1@example.com", "markvanlan2@example.com"],
    });
  });

  pretender.get("/admin/users/1234.json", () => {
    return response(200, {
      id: 1234,
      username: "regular",
    });
  });

  pretender.get("/admin/users/1235.json", () => {
    return response(200, {
      id: 1235,
      username: "regular2",
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
      extras: { user_history_actions: [] },
    });
  });

  pretender.get("/admin/customize/watched_words", () => {
    return response(200, fixturesByUrl["/admin/customize/watched_words.json"]);
  });
  pretender.delete("/admin/customize/watched_words/:id.json", success);

  pretender.post("/admin/customize/watched_words.json", (request) => {
    const result = parsePostData(request.requestBody);
    result.id = new Date().getTime();
    return response(200, result);
  });

  pretender.get("/admin/logs/search_logs.json", () => {
    return response(200, [
      { term: "foobar", searches: 35, click_through: 6, unique: 16 },
    ]);
  });

  pretender.get("/admin/logs/search_logs/term.json", () => {
    return response(200, {
      term: {
        type: "search_log_term",
        title: "Search Count",
        term: "ruby",
        data: [{ x: "2017-07-20", y: 2 }],
      },
    });
  });

  pretender.post("/uploads/lookup-metadata", () => {
    return response(200, {
      imageFilename: "somefile.png",
      imageFilesize: "10 KB",
      imageWidth: "1",
      imageHeight: "1",
    });
  });

  pretender.get("/color-scheme-stylesheet/2/1.json", () => {
    return response(200, {
      color_scheme_id: 2,
      new_href: "/stylesheets/color_definitions_scheme_name_2_hash.css",
    });
  });

  pretender.get("/inline-onebox", (request) => {
    if (
      request.queryParams.urls.includes("http://www.example.com/has-title.html")
    ) {
      return [
        200,
        { "Content-Type": "application/html" },
        '{"inline-oneboxes":[{"url":"http://www.example.com/has-title.html","title":"This is a great title"}]}',
      ];
    }
  });

  pretender.get("/onebox", (request) => {
    if (
      request.queryParams.url === "http://www.example.com/has-title.html" ||
      request.queryParams.url ===
        "http://www.example.com/has-title-and-a-url-that-is-more-than-80-characters-because-thats-good-for-seo-i-guess.html"
    ) {
      return [
        200,
        { "Content-Type": "application/html" },
        '<aside class="onebox"><article class="onebox-body"><h3><a href="http://www.example.com/article.html">An interesting article</a></h3></article></aside>',
      ];
    }

    if (request.queryParams.url === "http://www.example.com/no-title.html") {
      return [
        200,
        { "Content-Type": "application/html" },
        '<aside class="onebox"><article class="onebox-body"><p>No title</p></article></aside>',
      ];
    }

    if (
      request.queryParams.url === "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    ) {
      return [
        200,
        { "Content-Type": "application/html" },
        '<img src="https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg" width="480" height="360" title="Rick Astley - Never Gonna Give You Up (Video)">',
      ];
    }

    if (request.queryParams.url.indexOf("/internal-page.html") > -1) {
      return [
        200,
        { "Content-Type": "application/html" },
        '<aside class="onebox"><article class="onebox-body"><h3><a href="/internal-page.html">Internal Page 4 U</a></h3></article></aside>',
      ];
    }
    if (request.queryParams.url === "http://somegoodurl.com/") {
      return [
        200,
        { "Content-Type": "application/html" },
        `
    <aside class="onebox allowlistedgeneric">
      <header class="source">
          <a href="http://test.com/somepage" target="_blank">test.com</a>
      </header>
      <article class="onebox-body">
      <div class="aspect-image" style="--aspect-ratio:690/362;"><img src="" class="thumbnail"></div>
      <h3><a href="http://test.com/somepage" target="_blank">Test Page</a></h3>
      <p>Yet another collaboration tool</p>
      </article>
      <div class="onebox-metadata"></div>
      <div style="clear: both"></div>
    </aside>
  `,
      ];
    }

    if (
      request.queryParams.url ===
      "https://twitter.com/discourse/status/1357664660724482048"
    ) {
      return [
        200,
        { "Content-Type": "application/html" },
        `
        <aside class="onebox twitterstatus">
          <header class="source">
              <a href="https://twitter.com/discourse/status/1357664660724482048" target="_blank" rel="nofollow ugc noopener">twitter.com</a>
          </header>
          <article class="onebox-body">
            <img src="https://pbs.twimg.com/media/EtdhY-ZXYAAKyvo.jpg:large" class="thumbnail onebox-avatar">
        <h4><a href="https://twitter.com/discourse/status/1357664660724482048" target="_blank" rel="nofollow ugc noopener">Discourse (discourse)</a></h4>
        <div class="tweet"> Too busy to keep up with release notes? https://t.co/FQtGI5VrMl</div>
        <div class="date">
          <a href="https://twitter.com/discourse/status/1357664660724482048" target="_blank" rel="nofollow ugc noopener">4:17 AM - 5 Feb 2021</a>
            <span class="like">8</span>
            <span class="retweet">1</span>
        </div>
          </article>
          <div class="onebox-metadata"></div>
          <div style="clear: both"></div>
        </aside>
        `,
      ];
    }

    return [404, { "Content-Type": "application/html" }, ""];
  });

  pretender.get("edit-directory-columns.json", () => {
    return response(200, {
      directory_columns: [
        {
          id: 1,
          name: "likes_received",
          type: "automatic",
          enabled: true,
          automatic_position: 1,
          position: 1,
          icon: "heart",
          user_field: null,
        },
        {
          id: 2,
          name: "likes_given",
          type: "automatic",
          enabled: true,
          automatic_position: 2,
          position: 2,
          icon: "heart",
          user_field: null,
        },
        {
          id: 3,
          name: "topic_count",
          type: "automatic",
          enabled: true,
          automatic_position: 3,
          position: 3,
          icon: null,
          user_field: null,
        },
        {
          id: 4,
          name: "post_count",
          type: "automatic",
          enabled: true,
          automatic_position: 4,
          position: 4,
          icon: null,
          user_field: null,
        },
        {
          id: 5,
          name: "topics_entered",
          type: "automatic",
          enabled: true,
          automatic_position: 5,
          position: 5,
          icon: null,
          user_field: null,
        },
        {
          id: 6,
          name: "posts_read",
          type: "automatic",
          enabled: true,
          automatic_position: 6,
          position: 6,
          icon: null,
          user_field: null,
        },
        {
          id: 7,
          name: "days_visited",
          type: "automatic",
          enabled: true,
          automatic_position: 7,
          position: 7,
          icon: null,
          user_field: null,
        },
        {
          id: 9,
          name: null,
          type: "user_field",
          enabled: false,
          automatic_position: null,
          position: 8,
          icon: null,
          user_field: {
            id: 3,
            name: "Favorite Color",
            description: "User's favorite color",
            field_type: "text",
            editable: false,
            required: false,
            show_on_profile: false,
            show_on_user_card: true,
            searchable: true,
            position: 2,
          },
        },
      ],
    });
  });

  pretender.get("/directory-columns.json", () => {
    return response(200, {
      directory_columns: [
        {
          id: 1,
          name: "likes_received",
          type: "automatic",
          position: 1,
          icon: "heart",
          user_field: null,
        },
        {
          id: 2,
          name: "likes_given",
          type: "automatic",
          position: 2,
          icon: "heart",
          user_field: null,
        },
        {
          id: 3,
          name: "topic_count",
          type: "automatic",
          position: 3,
          icon: null,
          user_field: null,
        },
        {
          id: 4,
          name: "post_count",
          type: "automatic",
          position: 4,
          icon: null,
          user_field: null,
        },
        {
          id: 5,
          name: "topics_entered",
          type: "automatic",
          position: 5,
          icon: null,
          user_field: null,
        },
        {
          id: 6,
          name: "posts_read",
          type: "automatic",
          position: 6,
          icon: null,
          user_field: null,
        },
        {
          id: 7,
          name: "days_visited",
          type: "automatic",
          position: 7,
          icon: null,
          user_field: null,
        },
        {
          id: 9,
          name: "Favorite Color",
          type: "user_field",
          position: 8,
          icon: null,
          user_field_id: 3,
        },
      ],
    });
  });
}

export function resetPretender() {
  instance.handlers = [];
  instance.handledRequests = [];
  instance.unhandledRequests = [];
  instance.passthroughRequests = [];
}
