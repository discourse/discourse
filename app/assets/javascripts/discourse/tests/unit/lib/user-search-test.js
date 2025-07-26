import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import userSearch from "discourse/lib/user-search";
import { CANCELLED_STATUS } from "discourse/modifiers/d-autocomplete";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Utility | user-search", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/u/search/users", (request) => {
      // special responder for per category search
      const categoryMatch = request.url.match(/category_id=([0-9]+)/);
      if (categoryMatch) {
        if (categoryMatch[1] === "3") {
          return response({});
        }
        return response({
          users: [
            {
              username: `category_${categoryMatch[1]}`,
              name: "category user",
              avatar_template:
                "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
            },
          ],
        });
      }

      if (request.url.match(/no-results/)) {
        return response({ users: [] });
      }

      return response({
        users: [
          {
            username: "TeaMoe",
            name: "TeaMoe",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
          {
            username: "TeamOneJ",
            name: "J Cobb",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/3d9bf3/{size}.png",
          },
          {
            username: "kudos",
            name: "Team Blogeto.com",
            avatar_template:
              "/user_avatar/meta.discourse.org/kudos/{size}/62185_1.png",
          },
          {
            username: "RosieLinda",
            name: "Linda Teaman",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/r/bc8723/{size}.png",
          },
          {
            username: "legalatom",
            name: "Team LegalAtom",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/l/a9a28c/{size}.png",
          },
          {
            username: "dzsat_team",
            name: "Dz Sat Dz Sat",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/d/eb9ed0/{size}.png",
          },
        ],
        groups: [
          {
            name: "bob",
            usernames: [],
          },
          {
            name: "team",
            usernames: [],
          },
        ],
      });
    });
  });

  test("it flushes cache when switching categories", async function (assert) {
    let results = await userSearch({ term: "hello", categoryId: 1 });
    assert.strictEqual(results[0].username, "category_1");
    assert.strictEqual(results.length, 1);

    // this is cached ... so let's check the cache is good
    results = await userSearch({ term: "hello", categoryId: 1 });
    assert.strictEqual(results[0].username, "category_1");
    assert.strictEqual(results.length, 1);

    results = await userSearch({ term: "hello", categoryId: 2 });
    assert.strictEqual(results[0].username, "category_2");
    assert.strictEqual(results.length, 1);
  });

  test("it returns cancel when eager completing with no results", async function (assert) {
    // Do everything twice, to check the cache works correctly

    for (let i = 0; i < 2; i++) {
      // No topic or category, will always cancel
      let result = await userSearch({ term: "" });
      assert.strictEqual(result, CANCELLED_STATUS);
    }

    for (let i = 0; i < 2; i++) {
      // Unsecured category, so has no recommendations
      let result = await userSearch({ term: "", categoryId: 3 });
      assert.strictEqual(result, CANCELLED_STATUS);
    }

    for (let i = 0; i < 2; i++) {
      // Secured category, will have 1 recommendation
      let results = await userSearch({ term: "", categoryId: 1 });
      assert.strictEqual(results[0].username, "category_1");
      assert.strictEqual(results.length, 1);
    }
  });

  test("it strips @ from the beginning", async function (assert) {
    const results = await userSearch({ term: "@Team" });

    results.forEach((result) => {
      const identifier = result.username || result.name;
      assert.false(
        identifier.startsWith("@"),
        `Result '${identifier}' should not start with @`
      );
    });
  });

  test("it skips a search depending on punctuation", async function (assert) {
    let results;
    let skippedTerms = [
      "@sam  s", // double space is not allowed
      "@sam;",
      "@sam,",
      "@sam:",
    ];

    for (let term of skippedTerms) {
      results = await userSearch({ term });
      assert.strictEqual(results.length, 0);
    }

    let allowedTerms = [
      "@sam sam", // double space is not allowed
      "@sam.sam",
      "@sam_sam",
      "@sam-sam",
      "@",
    ];

    let topicId = 100;

    for (let term of allowedTerms) {
      results = await userSearch({ term, topicId });
      assert.strictEqual(results.length, 6);
    }

    results = await userSearch({ term: "sam@sam.com", allowEmails: true });
    assert.strictEqual(results.length, 6);

    results = await userSearch({ term: "sam+test@sam.com", allowEmails: true });
    assert.strictEqual(results.length, 6);

    results = await userSearch({ term: "sam@sam.com" });
    assert.strictEqual(results.length, 0);

    results = await userSearch({
      term: "no-results@example.com",
      allowEmails: true,
    });
    assert.strictEqual(results.length, 1);
  });

  test("it uses limit option", async function (assert) {
    const results = await userSearch({ term: "te", limit: 2 });
    assert.strictEqual(results.length, 2);
  });

  test("it orders results by priority: exact username, exact group, partial username, partial group, exact name, partial name, metadata", async function (assert) {
    pretender.get("/u/search/users", (request) => {
      if (request.url.includes("term=test")) {
        return response({
          users: [
            { username: "testing", name: "Testing User" }, // partial username match
            { username: "test", name: "Test User" }, // exact username match
            { username: "user123", name: "anon", title: "tester" }, // metadata match
            { username: "player", name: "test" }, // exact name match
            { username: "gamer", name: "testing games" }, // partial name match
          ],
          groups: [
            { name: "testers", usernames: [] }, // partial group match
            { name: "test", usernames: [] }, // exact group match
          ],
        });
      }
      return response({ users: [], groups: [] });
    });

    const results = await userSearch({
      term: "test",
      allowEmails: true,
      limit: 10,
    });

    // Expected order: exact username, exact group, partial username, partial group, exact name, partial name
    assert.strictEqual(
      results[0].username,
      "test",
      "Exact username match first"
    );
    assert.strictEqual(results[1].name, "test", "Exact group match second");
    assert.strictEqual(
      results[2].username,
      "testing",
      "Partial username match third"
    );
    assert.strictEqual(
      results[3].name,
      "testers",
      "Partial group match fourth"
    );
    assert.strictEqual(results[4].username, "player", "Exact name match fifth");
    assert.strictEqual(
      results[5].username,
      "gamer",
      "Partial name match sixth"
    );
    assert.strictEqual(results[6].username, "user123", "Metadata match last");
  });

  test("it includes all matching groups when limit allows", async function (assert) {
    pretender.get("/u/search/users", (request) => {
      if (request.url.includes("term=dev")) {
        return response({
          users: [{ username: "developer", name: "Developer" }],
          groups: [
            { name: "devs", usernames: [] },
            { name: "development", usernames: [] },
            { name: "dev-team", usernames: [] },
          ],
        });
      }
      return response({ users: [], groups: [] });
    });

    const results = await userSearch({ term: "dev", limit: 10 });
    const groupNames = results.groups.map((g) => g.name);

    // All groups should be included since limit allows
    ["devs", "development", "dev-team"].forEach((groupName) => {
      assert.true(
        groupNames.includes(groupName),
        `Should include '${groupName}' group`
      );
    });
  });
});
