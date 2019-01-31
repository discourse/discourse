import storePretender from "helpers/store-pretender";
import fixturePretender from "helpers/fixture-pretender";
import flagPretender from "helpers/flag-pretender";

export function parsePostData(query) {
  const result = {};
  query.split("&").forEach(function(part) {
    const item = part.split("=");
    const firstSeg = decodeURIComponent(item[0]);
    const m = /^([^\[]+)\[([^\]]+)\]/.exec(firstSeg);

    const val = decodeURIComponent(item[1]).replace(/\+/g, " ");
    if (m) {
      result[m[1]] = result[m[1]] || {};
      result[m[1]][m[2]] = val;
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

const loggedIn = () => !!Discourse.User.current();
const helpers = { response, success, parsePostData };
export let fixturesByUrl;

export default function() {
  const server = new Pretender(function() {
    storePretender.call(this, helpers);
    flagPretender.call(this, helpers);
    fixturesByUrl = fixturePretender.call(this, helpers);

    this.get("/admin/plugins", () => response({ plugins: [] }));

    this.get("/composer_messages", () => response({ composer_messages: [] }));

    this.get("/latest.json", () => {
      const json = fixturesByUrl["/latest.json"];

      if (loggedIn()) {
        // Stuff to let us post
        json.topic_list.can_create_topic = true;
        json.topic_list.draft_key = "new_topic";
        json.topic_list.draft_sequence = 1;
      }
      return response(json);
    });

    this.get("/tags", () => {
      return response({
        tags: [
          {
            id: "eviltrout",
            count: 1
          }
        ]
      });
    });

    this.get(`/u/:username/emails.json`, () => {
      return response({ email: "eviltrout@example.com" });
    });

    this.get("/u/eviltrout.json", () => {
      const json = fixturesByUrl["/u/eviltrout.json"];
      json.user.can_edit = loggedIn();
      return response(json);
    });

    this.get("/u/eviltrout/summary.json", () => {
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

    this.get("/u/eviltrout/invited_count.json", () => {
      return response({
        counts: { pending: 1, redeemed: 0, total: 0 }
      });
    });

    this.get("/u/eviltrout/invited.json", () => {
      return response({ invites: [{ id: 1 }] });
    });

    this.get("/topics/private-messages/eviltrout.json", () => {
      return response({ topic_list: { topics: [] } });
    });

    this.get("/clicks/track", success);

    this.get("/search", request => {
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

    this.put("/u/eviltrout.json", () => response({ user: {} }));

    this.get("/t/280.json", () => response(fixturesByUrl["/t/280/1.json"]));
    this.get("/t/280/20.json", () => response(fixturesByUrl["/t/280/1.json"]));
    this.get("/t/28830.json", () => response(fixturesByUrl["/t/28830/1.json"]));
    this.get("/t/9.json", () => response(fixturesByUrl["/t/9/1.json"]));
    this.get("/t/12.json", () => response(fixturesByUrl["/t/12/1.json"]));
    this.put("/t/1234/re-pin", success);

    this.get("/t/id_for/:slug", () => {
      return response({
        id: 280,
        slug: "internationalization-localization",
        url: "/t/internationalization-localization/280"
      });
    });

    this.delete("/t/:id", success);
    this.put("/t/:id/recover", success);
    this.put("/t/:id/publish", success);

    this.get("/404-body", () => {
      return [
        200,
        { "Content-Type": "text/html" },
        "<div class='page-not-found'>not found</div>"
      ];
    });

    this.delete("/draft.json", success);
    this.post("/draft.json", success);

    this.get("/u/:username/staff-info.json", () => response({}));

    this.get("/post_action_users", () => {
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

    this.get("/post_replies", () => {
      return response({ post_replies: [{ id: 1234, cooked: "wat" }] });
    });

    this.get("/post_reply_histories", () => {
      return response({ post_reply_histories: [{ id: 1234, cooked: "wat" }] });
    });

    this.get("/category_hashtags/check", () => {
      return response({ valid: [{ slug: "bug", url: "/c/bugs" }] });
    });

    this.get("/categories_and_latest", () =>
      response(fixturesByUrl["/categories_and_latest.json"])
    );

    this.put("/categories/:category_id", request => {
      const category = parsePostData(request.requestBody);

      if (category.email_in === "duplicate@example.com") {
        return response(422, { errors: ["duplicate email"] });
      }

      return response({ category });
    });

    this.get("/draft.json", request => {
      if (request.queryParams.draft_key === "new_topic") {
        return response(fixturesByUrl["/draft.json"]);
      }

      return response({});
    });

    this.get("/drafts.json", () => response(fixturesByUrl["/drafts.json"]));

    this.put("/queued_posts/:queued_post_id", function(request) {
      return response({ queued_post: { id: request.params.queued_post_id } });
    });

    this.get("/queued_posts", function() {
      return response({
        queued_posts: [
          { id: 1, raw: "queued post text", can_delete_user: true }
        ]
      });
    });

    this.post("/session", function(request) {
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
          error: "Invalid Second Factor",
          reason: "invalid_second_factor",
          backup_enabled: true,
          sent_to_email: "eviltrout@example.com",
          current_email: "current@example.com"
        });
      }

      return response(400, { error: "invalid login" });
    });

    this.post("/u/action/send_activation_email", success);
    this.put("/u/update-activation-email", success);

    this.get("/u/hp.json", function() {
      return response({
        value: "32faff1b1ef1ac3",
        challenge: "61a3de0ccf086fb9604b76e884d75801"
      });
    });

    this.get("/session/csrf", function() {
      return response({ csrf: "mgk906YLagHo2gOgM1ddYjAN4hQolBdJCqlY6jYzAYs=" });
    });

    this.get("/groups/check-name", () => {
      return response({ available: true });
    });

    this.get("/u/check_username", function(request) {
      if (request.queryParams.username === "taken") {
        return response({ available: false, suggestion: "nottaken" });
      }
      return response({ available: true });
    });

    this.post("/u", () => response({ success: true }));

    this.get("/login.html", () => [200, {}, "LOGIN PAGE"]);

    this.delete("/posts/:post_id", success);
    this.put("/posts/:post_id/recover", success);
    this.get("/posts/:post_id/expand-embed", success);

    this.put("/posts/:post_id", request => {
      const data = parsePostData(request.requestBody);
      data.post.id = request.params.post_id;
      data.post.version = 2;
      return response(200, data.post);
    });

    this.get("/t/403.json", () => response(403, {}));
    this.get("/t/404.json", () => response(404, "not found"));
    this.get("/t/500.json", () => response(502, {}));

    this.put("/t/:slug/:id", request => {
      const data = parsePostData(request.requestBody);

      return response(200, {
        basic_topic: {
          id: request.params.id,
          title: data.title,
          fancy_title: data.title,
          slug: request.params.slug
        }
      });
    });

    this.get("groups", () => {
      return response(200, fixturesByUrl["/groups.json"]);
    });

    this.get("/groups.json", () => {
      return response(200, fixturesByUrl["/groups.json?username=eviltrout"]);
    });

    this.get("groups/search.json", () => {
      return response(200, []);
    });

    this.get("/topics/groups/discourse.json", () => {
      return response(200, fixturesByUrl["/topics/groups/discourse.json"]);
    });

    this.get("/groups/discourse/mentions.json", () => {
      return response(200, fixturesByUrl["/groups/discourse/posts.json"]);
    });

    this.get("/groups/discourse/messages.json", () => {
      return response(200, fixturesByUrl["/groups/discourse/posts.json"]);
    });

    this.get("/groups/moderators/members.json", () => {
      return response(200, fixturesByUrl["/groups/discourse/members.json"]);
    });

    this.get("/t/:topic_id/posts.json", request => {
      const postIds = request.queryParams.post_ids;
      const postNumber = parseInt(request.queryParams.post_number);
      let posts;

      if (postIds) {
        posts = postIds.map(p => ({
          id: parseInt(p),
          post_number: parseInt(p)
        }));
      } else if (postNumber && request.queryParams.asc === "true") {
        posts = _.range(postNumber + 1, postNumber + 6).map(p => ({
          id: parseInt(p),
          post_number: parseInt(p)
        }));
      } else if (postNumber && request.queryParams.asc === "false") {
        posts = _.range(postNumber - 5, postNumber)
          .reverse()
          .map(p => ({
            id: parseInt(p),
            post_number: parseInt(p)
          }));
      }

      return response(200, { post_stream: { posts } });
    });

    this.get("/posts/:post_id/reply-history.json", () => {
      return response(200, [{ id: 2222, post_number: 2222 }]);
    });

    this.get("/posts/:post_id/reply-ids.json", () => {
      return response(200, {
        direct_reply_ids: [45],
        all_reply_ids: [45, 100]
      });
    });

    this.post("/user_badges", () =>
      response(200, fixturesByUrl["/user_badges"])
    );
    this.delete("/user_badges/:badge_id", success);

    this.post("/posts", function(request) {
      const data = parsePostData(request.requestBody);

      if (data.title === "this title triggers an error") {
        return response(422, { errors: ["That title has already been taken"] });
      }

      if (data.raw === "enqueue this content please") {
        return response(200, { success: true, action: "enqueued" });
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

    this.post("/topics/timings", () => response(200, {}));

    const siteText = { id: "site.test", value: "Test McTest" };
    const overridden = {
      id: "site.overridden",
      value: "Overridden",
      overridden: true
    };

    this.get("/admin/users/list/active.json", () => {
      return response(200, [
        {
          id: 1,
          username: "eviltrout",
          email: "<small>eviltrout@example.com</small>"
        }
      ]);
    });

    this.get("/admin/customize/site_texts", request => {
      if (request.queryParams.overridden) {
        return response(200, { site_texts: [overridden] });
      } else {
        return response(200, { site_texts: [siteText, overridden] });
      }
    });

    this.get("/admin/customize/site_texts/:key", () =>
      response(200, { site_text: siteText })
    );
    this.delete("/admin/customize/site_texts/:key", () =>
      response(200, { site_text: siteText })
    );

    this.put("/admin/customize/site_texts/:key", request => {
      const result = parsePostData(request.requestBody);
      result.id = request.params.key;
      result.can_revert = true;
      return response(200, { site_text: result });
    });

    this.get("/tag_groups", () => response(200, { tag_groups: [] }));

    this.get("/admin/users/1234.json", () => {
      return response(200, {
        id: 1234,
        username: "regular"
      });
    });

    this.get("/admin/users/2.json", () => {
      return response(200, {
        id: 2,
        username: "sam",
        admin: true
      });
    });

    this.post("/admin/users/:user_id/generate_api_key", success);
    this.delete("/admin/users/:user_id/revoke_api_key", success);
    this.delete("/admin/users/:user_id.json", () =>
      response(200, { deleted: true })
    );
    this.post("/admin/badges", success);
    this.delete("/admin/badges/:id", success);

    this.get("/admin/logs/staff_action_logs.json", () => {
      return response(200, { staff_action_logs: [], user_history_actions: [] });
    });

    this.get("/admin/logs/watched_words", () => {
      return response(200, fixturesByUrl["/admin/logs/watched_words.json"]);
    });
    this.delete("/admin/logs/watched_words/:id.json", success);

    this.post("/admin/logs/watched_words.json", request => {
      const result = parsePostData(request.requestBody);
      result.id = new Date().getTime();
      return response(200, result);
    });

    this.get("/admin/logs/search_logs.json", () => {
      return response(200, [
        { term: "foobar", searches: 35, click_through: 6, unique: 16 }
      ]);
    });

    this.get("/admin/logs/search_logs/term/ruby.json", () => {
      return response(200, {
        term: {
          type: "search_log_term",
          title: "Search Count",
          data: [{ x: "2017-07-20", y: 2 }]
        }
      });
    });

    this.get("/inline-onebox", request => {
      if (
        request.queryParams.urls.includes(
          "http://www.example.com/has-title.html"
        )
      ) {
        return [
          200,
          { "Content-Type": "application/html" },
          '{"inline-oneboxes":[{"url":"http://www.example.com/has-title.html","title":"This is a great title"}]}'
        ];
      }
    });

    this.get("/onebox", request => {
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

      return [404, { "Content-Type": "application/html" }, ""];
    });
  });

  server.prepareBody = function(body) {
    if (body && typeof body === "object") {
      return JSON.stringify(body);
    }
    return body;
  };

  server.unhandledRequest = function(verb, path) {
    const error =
      "Unhandled request in test environment: " + path + " (" + verb + ")";
    window.console.error(error);
    throw error;
  };

  server.checkPassthrough = request =>
    request.requestHeaders["Discourse-Script"];
  return server;
}
