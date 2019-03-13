import userSearch from "discourse/lib/user-search";

QUnit.module("lib:user-search", {
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    // prettier-ignore
    server.get("/u/search/users", () => { //eslint-disable-line
      return response({
        users: [
          {
            username: "TeaMoe",
            name: "TeaMoe",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png"
          },
          {
            username: "TeamOneJ",
            name: "J Cobb",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/3d9bf3/{size}.png"
          },
          {
            username: "kudos",
            name: "Team Blogeto.com",
            avatar_template:
              "/user_avatar/meta.discourse.org/kudos/{size}/62185_1.png"
          },
          {
            username: "RosieLinda",
            name: "Linda Teaman",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/r/bc8723/{size}.png"
          },
          {
            username: "legalatom",
            name: "Team LegalAtom",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/l/a9a28c/{size}.png"
          },
          {
            username: "dzsat_team",
            name: "Dz Sat Dz Sat",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/d/eb9ed0/{size}.png"
          }
        ],
        groups: [
          {
            name: "bob",
            usernames: []
          },
          {
            name: "team",
            usernames: []
          }
        ]
      });
    });
  }
});

QUnit.test("it places groups unconditionally for exact match", async assert => {
  let results = await userSearch({ term: "Team" });
  assert.equal(results[results.length - 1]["name"], "team");
});

QUnit.test("it strips @ from the beginning", async assert => {
  let results = await userSearch({ term: "@Team" });
  assert.equal(results[results.length - 1]["name"], "team");
});

QUnit.test("it skips a search depending on punctuations", async assert => {
  let results;
  let skippedTerms = [
    "@sam  s", // double space is not allowed
    "@sam;",
    "@sam,",
    "@sam:"
  ];

  for (let term of skippedTerms) {
    results = await userSearch({ term });
    assert.equal(results.length, 0);
  }

  let allowedTerms = [
    "@sam sam", // double space is not allowed
    "@sam.sam",
    "@sam_sam",
    "@sam-sam",
    "@"
  ];

  let topicId = 100;

  for (let term of allowedTerms) {
    results = await userSearch({ term, topicId });
    assert.equal(results.length, 6);
  }

  results = await userSearch({ term: "sam@sam.com", allowEmails: true });
  // 6 + email
  assert.equal(results.length, 7);

  results = await userSearch({ term: "sam@sam.com" });
  assert.equal(results.length, 0);
});
