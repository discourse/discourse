import { acceptance, waitFor } from "helpers/qunit-helpers";
acceptance("Search - Full Page", {
  settings: { tagging_enabled: true },
  loggedIn: true,
  pretend(server, helper) {
    server.get("/tags/filter/search", () => {
      return helper.response({ results: [{ text: "monkey", count: 1 }] });
    });

    server.get("/u/search/users", () => {
      return helper.response({
        users: [
          {
            username: "admin",
            name: "admin",
            avatar_template: "/images/avatar.png"
          }
        ]
      });
    });

    server.get("/admin/groups.json", () => {
      return helper.response({
        id: 2,
        automatic: true,
        name: "moderators",
        user_count: 4,
        alias_level: 0,
        visible: true,
        automatic_membership_email_domains: null,
        automatic_membership_retroactive: false,
        primary_group: false,
        title: null,
        grant_trust_level: null,
        incoming_email: null,
        notification_level: null,
        has_messages: true,
        is_member: true,
        mentionable: false,
        flair_url: null,
        flair_bg_color: null,
        flair_color: null
      });
    });

    server.get("/badges.json", () => {
      return helper.response({
        badge_types: [{ id: 3, name: "Bronze", sort_order: 7 }],
        badge_groupings: [
          {
            id: 1,
            name: "Getting Started",
            description: null,
            position: 10,
            system: true
          }
        ],
        badges: [
          {
            id: 17,
            name: "Reader",
            description:
              "Read every reply in a topic with more than 100 replies",
            grant_count: 0,
            allow_title: false,
            multiple_grant: false,
            icon: "fa-certificate",
            image: null,
            listable: true,
            enabled: true,
            badge_grouping_id: 1,
            system: true,
            long_description:
              "This badge is granted the first time you read a long topic with more than 100 replies. Reading a conversation closely helps you follow the discussion, understand different viewpoints, and leads to more interesting conversations. The more you read, the better the conversation gets. As we like to say, Reading is Fundamental! :slight_smile:\n",
            slug: "reader",
            has_badge: false,
            badge_type_id: 3
          }
        ]
      });
    });
  }
});

QUnit.test("perform various searches", async assert => {
  await visit("/search");

  assert.ok($("body.search-page").length, "has body class");
  assert.ok(exists(".search-container"), "has container class");
  assert.ok(find(".search-query").length > 0);
  assert.ok(find(".fps-topic").length === 0);

  await fillIn(".search-query", "none");
  await click(".search-cta");

  assert.ok(find(".fps-topic").length === 0, "has no results");
  assert.ok(find(".no-results-suggestion .google-search-form"));

  await fillIn(".search-query", "posts");
  await click(".search-cta");

  assert.ok(find(".fps-topic").length === 1, "has one post");
});

QUnit.test("escape search term", async assert => {
  await visit("/search");
  await fillIn(".search-query", "@<script>prompt(1337)</script>gmail.com");

  assert.ok(
    exists(
      '.search-advanced-options span:contains("<script>prompt(1337)</script>gmail.com")'
    ),
    "it escapes search term"
  );
});

QUnit.test("update username through advanced search ui", async assert => {
  await visit("/search");
  await fillIn(".search-query", "none");
  await fillIn(".search-advanced-options .user-selector", "admin");
  await click(".search-advanced-options .user-selector");
  await keyEvent(".search-advanced-options .user-selector", "keydown", 8);

  waitFor(assert, async () => {
    assert.ok(
      visible(".search-advanced-options .autocomplete"),
      '"autocomplete" popup is visible'
    );
    assert.ok(
      exists(
        '.search-advanced-options .autocomplete ul li a span.username:contains("admin")'
      ),
      '"autocomplete" popup has an entry for "admin"'
    );

    await click(".search-advanced-options .autocomplete ul li a:first");

    assert.ok(
      exists('.search-advanced-options span:contains("admin")'),
      'has "admin" pre-populated'
    );
    assert.equal(
      find(".search-query").val(),
      "none @admin",
      'has updated search term to "none user:admin"'
    );
  });
});

QUnit.test("update category through advanced search ui", async assert => {
  const categoryChooser = selectKit(
    ".search-advanced-options .category-chooser"
  );

  await visit("/search");

  await fillIn(".search-query", "none");

  await categoryChooser.expand();
  await categoryChooser.fillInFilter("faq");
  await categoryChooser.selectRowByValue(4);

  assert.ok(
    exists('.search-advanced-options .badge-category:contains("faq")'),
    'has "faq" populated'
  );
  assert.equal(
    find(".search-query").val(),
    "none #faq",
    'has updated search term to "none #faq"'
  );
});

// test("update group through advanced search ui", assert => {
//   visit("/search");
//   fillIn('.search-query', 'none');
//
//   fillIn('.search-advanced-options .group-selector', 'moderators');
//   click('.search-advanced-options .group-selector');
//   keyEvent('.search-advanced-options .group-selector', 'keydown', 8);
//
//   andThen(() => {
//     waitFor(() => {
//       assert.ok(visible('.search-advanced-options .autocomplete'), '"autocomplete" popup is visible');
//       assert.ok(exists('.search-advanced-options .autocomplete ul li a:contains("moderators")'), '"autocomplete" popup has an entry for "moderators"');
//
//       click('.search-advanced-options .autocomplete ul li a:first');
//
//       andThen(() => {
//         assert.ok(exists('.search-advanced-options span:contains("moderators")'), 'has "moderators" pre-populated');
//         assert.equal(find('.search-query').val(), "none group:moderators", 'has updated search term to "none group:moderators"');
//       });
//     });
//   });
// });

// test("update badges through advanced search ui", assert => {
//   visit("/search");
//   fillIn('.search-query', 'none');
//
//   fillIn('.search-advanced-options .badge-names', 'Reader');
//   click('.search-advanced-options .badge-names');
//   keyEvent('.search-advanced-options .badge-names', 'keydown', 8);
//
//   andThen(() => {
//     waitFor(() => {
//       assert.ok(visible('.search-advanced-options .autocomplete'), '"autocomplete" popup is visible');
//       assert.ok(exists('.search-advanced-options .autocomplete ul li a:contains("Reader")'), '"autocomplete" popup has an entry for "Reader"');
//
//       click('.search-advanced-options .autocomplete ul li a:first');
//
//       andThen(() => {
//         assert.ok(exists('.search-advanced-options span:contains("Reader")'), 'has "Reader" pre-populated');
//         assert.equal(find('.search-query').val(), "none badge:Reader", 'has updated search term to "none badge:Reader"');
//       });
//     });
//   });
// });

// test("update tags through advanced search ui", assert => {
//   visit("/search");
//   fillIn('.search-query', 'none');
//
//
//   keyEvent('.search-advanced-options .tag-chooser input.select2-input', 'keydown', 110);
//   fillIn('.search-advanced-options .tag-chooser input.select2-input', 'monkey');
//   keyEvent('.search-advanced-options .tag-chooser input.select2-input', 'keyup', 110);
//
//   andThen(() => {
//     waitFor(() => {
//       click('li.select2-result-selectable:first');
//       andThen(() => {
//         assert.ok(exists('.search-advanced-options .tag-chooser .tag-monkey'), 'has "monkey" pre-populated');
//         assert.equal(find('.search-query').val(), "none tags:monkey", 'has updated search term to "none tags:monkey"');
//       });
//     });
//   });
// });
//
QUnit.test(
  "update in:title filter through advanced search ui",
  async assert => {
    await visit("/search");
    await fillIn(".search-query", "none");
    await click(".search-advanced-options .in-title");

    assert.ok(
      exists(".search-advanced-options .in-title:checked"),
      'has "in title" populated'
    );
    assert.equal(
      find(".search-query").val(),
      "none in:title",
      'has updated search term to "none in:title"'
    );
  }
);

QUnit.test(
  "update in:likes filter through advanced search ui",
  async assert => {
    await visit("/search");
    await fillIn(".search-query", "none");
    await click(".search-advanced-options .in-likes");

    assert.ok(
      exists(".search-advanced-options .in-likes:checked"),
      'has "I liked" populated'
    );
    assert.equal(
      find(".search-query").val(),
      "none in:likes",
      'has updated search term to "none in:likes"'
    );
  }
);

QUnit.test(
  "update in:private filter through advanced search ui",
  async assert => {
    await visit("/search");
    await fillIn(".search-query", "none");
    await click(".search-advanced-options .in-private");

    assert.ok(
      exists(".search-advanced-options .in-private:checked"),
      'has "are in my messages" populated'
    );
    assert.equal(
      find(".search-query").val(),
      "none in:private",
      'has updated search term to "none in:private"'
    );
  }
);

QUnit.test("update in:seen filter through advanced search ui", async assert => {
  await visit("/search");
  await fillIn(".search-query", "none");
  await click(".search-advanced-options .in-seen");

  assert.ok(
    exists(".search-advanced-options .in-seen:checked"),
    "it should check the right checkbox"
  );

  assert.equal(
    find(".search-query").val(),
    "none in:seen",
    "it should update the search term"
  );
});

QUnit.test("update in filter through advanced search ui", async assert => {
  const inSelector = selectKit(".search-advanced-options .select-kit#in");

  await visit("/search");

  await fillIn(".search-query", "none");
  await inSelector.expand();
  await inSelector.selectRowByValue("bookmarks");

  assert.ok(
    inSelector.rowByName("I bookmarked").exists(),
    'has "I bookmarked" populated'
  );
  assert.equal(
    find(".search-query").val(),
    "none in:bookmarks",
    'has updated search term to "none in:bookmarks"'
  );
});

QUnit.test("update status through advanced search ui", async assert => {
  const statusSelector = selectKit(
    ".search-advanced-options .select-kit#status"
  );

  await visit("/search");

  await fillIn(".search-query", "none");
  await statusSelector.expand();
  await statusSelector.selectRowByValue("closed");

  assert.ok(
    statusSelector.rowByName("are closed").exists(),
    'has "are closed" populated'
  );
  assert.equal(
    find(".search-query").val(),
    "none status:closed",
    'has updated search term to "none status:closed"'
  );
});

QUnit.test("update post time through advanced search ui", async assert => {
  await visit("/search?expanded=true&q=after:2018-08-22");

  assert.equal(
    find(".search-query").val(),
    "after:2018-08-22",
    "it should update the search term correctly"
  );

  const postTimeSelector = selectKit(
    ".search-advanced-options .select-kit#postTime"
  );

  await visit("/search");

  await fillIn(".search-query", "none");
  await fillIn("#search-post-date .date-picker", "2016-10-05");
  await postTimeSelector.expand();
  await postTimeSelector.selectRowByValue("after");

  assert.ok(
    postTimeSelector.rowByName("after").exists(),
    'has "after" populated'
  );

  assert.equal(
    find(".search-query").val(),
    "none after:2016-10-05",
    'has updated search term to "none after:2016-10-05"'
  );
});

QUnit.test("update min post count through advanced search ui", async assert => {
  await visit("/search");
  await fillIn(".search-query", "none");
  await fillIn("#search-min-post-count", "5");

  assert.equal(
    find(".search-advanced-options #search-min-post-count").val(),
    "5",
    'has "5" populated'
  );
  assert.equal(
    find(".search-query").val(),
    "none min_post_count:5",
    'has updated search term to "none min_post_count:5"'
  );
});

QUnit.test("validate advanced search when initially empty", async assert => {
  await visit("/search?expanded=true");
  await click(".search-advanced-options .in-likes");

  assert.ok(
    exists(".search-advanced-options .in-likes:checked"),
    'has "I liked" populated'
  );
  assert.equal(
    find(".search-query").val(),
    "in:likes",
    'has updated search term to "in:likes"'
  );
});
