import { acceptance, waitFor } from "helpers/qunit-helpers";
acceptance("Search - Full Page", {
  settings: {tagging_enabled: true},
  loggedIn: true,
  beforeEach() {
    const response = (object) => {
      return [
        200,
        {"Content-Type": "application/json"},
        object
      ];
    };

    server.get('/tags/filter/search', () => { //eslint-disable-line
      return response({results: [{text: 'monkey', count: 1}]});
    });

    server.get('/u/search/users', () => { //eslint-disable-line
      return response({users: [{username: "admin", name: "admin",
        avatar_template: "/images/avatar.png"}]});
    });

    server.get('/admin/groups.json', () => { //eslint-disable-line
      return response([{id: 2, automatic: true, name: "moderators", user_count: 4, alias_level: 0,
        visible: true, automatic_membership_email_domains: null, automatic_membership_retroactive: false,
        primary_group: false, title: null, grant_trust_level: null, incoming_email: null,
        notification_level: null, has_messages: true, is_member: true, mentionable: false,
        flair_url: null, flair_bg_color: null, flair_color: null}]);
    });

    server.get('/badges.json', () => { //eslint-disable-line
      return response({badge_types: [{id: 3, name: "Bronze", sort_order: 7}],
        badge_groupings: [{id: 1, name: "Getting Started", description: null, position: 10, system: true}],
        badges: [{id: 17, name: "Reader", description: "Read every reply in a topic with more than 100 replies",
          grant_count: 0, allow_title: false, multiple_grant: false, icon: "fa-certificate", image: null,
          listable: true, enabled: true, badge_grouping_id: 1, system: true,
          long_description: "This badge is granted the first time you read a long topic with more than 100 replies. Reading a conversation closely helps you follow the discussion, understand different viewpoints, and leads to more interesting conversations. The more you read, the better the conversation gets. As we like to say, Reading is Fundamental! :slight_smile:\n",
          slug: "reader", has_badge: false, badge_type_id: 3}]});
    });
  }
});

QUnit.test("perform various searches", assert => {
  visit("/search");

  andThen(() => {
    assert.ok($('body.search-page').length, "has body class");
    assert.ok(exists('.search-container'), "has container class");
    assert.ok(find('input.search').length > 0);
    assert.ok(find('.fps-topic').length === 0);
  });

  fillIn('.search input.full-page-search', 'none');
  click('.search .btn-primary');

  andThen(() => {
    assert.ok(find('.fps-topic').length === 0, 'has no results');
    assert.ok(find('.no-results-suggestion .google-search-form'));
  });

  fillIn('.search input.full-page-search', 'posts');
  click('.search .btn-primary');

  andThen(() => assert.ok(find('.fps-topic').length === 1, 'has one post'));
});

QUnit.test("open advanced search", assert => {
  visit("/search");

  andThen(() => assert.ok(exists('.search .search-advanced'), 'shows advanced search panel'));

  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced-btn');

  andThen(() => assert.ok(visible('.search-advanced .search-advanced-options'), '"search-advanced-options" is visible'));
});

// these tests are screwy with the runloop

// test("validate population of advanced search", assert => {
//   visit("/search");
//   fillIn('.search input.full-page-search', 'test user:admin #bug group:moderators badge:Reader tags:monkey in:likes in:private in:wiki in:bookmarks status:open after:2016-10-05 min_post_count:10');
//   click('.search-advanced-btn');
//
//   andThen(() => {
//     assert.ok(exists('.search-advanced-options span:contains("admin")'), 'has "admin" pre-populated');
//     assert.ok(exists('.search-advanced-options .badge-category:contains("bug")'), 'has "bug" pre-populated');
//     //assert.ok(exists('.search-advanced-options span:contains("moderators")'), 'has "moderators" pre-populated');
//     //assert.ok(exists('.search-advanced-options span:contains("Reader")'), 'has "Reader" pre-populated');
//     assert.ok(exists('.search-advanced-options .tag-chooser .tag-monkey'), 'has "monkey" pre-populated');
//     assert.ok(exists('.search-advanced-options .in-likes:checked'), 'has "I liked" pre-populated');
//     assert.ok(exists('.search-advanced-options .in-private:checked'), 'has "are in my messages" pre-populated');
//     assert.ok(exists('.search-advanced-options .in-wiki:checked'), 'has "are wiki" pre-populated');
//     assert.ok(exists('.search-advanced-options .combobox .select2-choice .select2-chosen:contains("I\'ve bookmarked")'), 'has "I\'ve bookmarked" pre-populated');
//     assert.ok(exists('.search-advanced-options .combobox .select2-choice .select2-chosen:contains("are open")'), 'has "are open" pre-populated');
//     assert.ok(exists('.search-advanced-options .combobox .select2-choice .select2-chosen:contains("after")'), 'has "after" pre-populated');
//     assert.equal(find('.search-advanced-options #search-post-date').val(), "2016-10-05", 'has "2016-10-05" pre-populated');
//     assert.equal(find('.search-advanced-options #search-min-post-count').val(), "10", 'has "10" pre-populated');
//   });
// });

QUnit.test("escape search term", (assert) => {
  visit("/search");
  fillIn('.search input.full-page-search', '@<script>prompt(1337)</script>gmail.com');
  click('.search-advanced-btn');

  andThen(() => {
    assert.ok(exists('.search-advanced-options span:contains("<script>prompt(1337)</script>gmail.com")'), 'it escapes search term');
  });
});

QUnit.test("update username through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced-btn');
  fillIn('.search-advanced-options .user-selector', 'admin');
  click('.search-advanced-options .user-selector');
  keyEvent('.search-advanced-options .user-selector', 'keydown', 8);

  andThen(() => {
    waitFor(assert, () => {
      assert.ok(visible('.search-advanced-options .autocomplete'), '"autocomplete" popup is visible');
      assert.ok(exists('.search-advanced-options .autocomplete ul li a span.username:contains("admin")'), '"autocomplete" popup has an entry for "admin"');

      click('.search-advanced-options .autocomplete ul li a:first');

      andThen(() => {
        assert.ok(exists('.search-advanced-options span:contains("admin")'), 'has "admin" pre-populated');
        assert.equal(find('.search input.full-page-search').val(), "none @admin", 'has updated search term to "none user:admin"');
      });
    });
  });
});

QUnit.test("update category through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced-btn');
  fillIn('.search-advanced-options .category-selector', 'faq');
  click('.search-advanced-options .category-selector');
  keyEvent('.search-advanced-options .category-selector', 'keydown', 8);
  keyEvent('.search-advanced-options .category-selector', 'keydown', 9);

  andThen(() => {
    assert.ok(exists('.search-advanced-options .badge-category:contains("faq")'), 'has "faq" populated');
    assert.equal(find('.search input.full-page-search').val(), "none #faq", 'has updated search term to "none #faq"');
  });
});

// test("update group through advanced search ui", assert => {
//   visit("/search");
//   fillIn('.search input.full-page-search', 'none');
//   click('.search-advanced-btn');
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
//         assert.equal(find('.search input.full-page-search').val(), "none group:moderators", 'has updated search term to "none group:moderators"');
//       });
//     });
//   });
// });

// test("update badges through advanced search ui", assert => {
//   visit("/search");
//   fillIn('.search input.full-page-search', 'none');
//   click('.search-advanced-btn');
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
//         assert.equal(find('.search input.full-page-search').val(), "none badge:Reader", 'has updated search term to "none badge:Reader"');
//       });
//     });
//   });
// });

// test("update tags through advanced search ui", assert => {
//   visit("/search");
//   fillIn('.search input.full-page-search', 'none');
//   click('.search-advanced-btn');
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
//         assert.equal(find('.search input.full-page-search').val(), "none tags:monkey", 'has updated search term to "none tags:monkey"');
//       });
//     });
//   });
// });

QUnit.test("update in:likes filter through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced-btn');
  click('.search-advanced-options .in-likes');

  andThen(() => {
    assert.ok(exists('.search-advanced-options .in-likes:checked'), 'has "I liked" populated');
    assert.equal(find('.search input.full-page-search').val(), "none in:likes", 'has updated search term to "none in:likes"');
  });
});

QUnit.test("update in:private filter through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced-btn');
  click('.search-advanced-options .in-private');

  andThen(() => {
    assert.ok(exists('.search-advanced-options .in-private:checked'), 'has "are in my messages" populated');
    assert.equal(find('.search input.full-page-search').val(), "none in:private", 'has updated search term to "none in:private"');
  });
});

QUnit.test("update in:seen filter through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced-btn');
  click('.search-advanced-options .in-seen');

  andThen(() => {
    assert.ok(exists('.search-advanced-options .in-seen:checked'), 'it should check the right checkbox');

    assert.equal(find('.search input.full-page-search').val(), "none in:seen",
      'it should update the search term'
    );
  });
});

QUnit.test("update in filter through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced-btn');

  expandSelectBox('.search-advanced-options .select-box-kit#in');
  selectBoxSelectRow('bookmarks', { selector: '.search-advanced-options .select-box-kit#in' });
  fillIn('.search-advanced-options .select-box-kit#in', 'bookmarks');

  andThen(() => {
    assert.ok(exists(selectBox('.search-advanced-options .select-box-kit#in').rowByName("I\'ve bookmarked").el), 'has "I\'ve bookmarked" populated');
    assert.equal(find('.search input.full-page-search').val(), "none in:bookmarks", 'has updated search term to "none in:bookmarks"');
  });
});

QUnit.test("update status through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced-btn');
  expandSelectBox('.search-advanced-options .select-box-kit#status');
  selectBoxSelectRow('closed', { selector: '.search-advanced-options .select-box-kit#status' });
  fillIn('.search-advanced-options .select-box-kit#status', 'closed');

  andThen(() => {
    assert.ok(exists(selectBox('.search-advanced-options .select-box-kit#status').rowByName("are closed").el), 'has "are closed" populated');
    assert.equal(find('.search input.full-page-search').val(), "none status:closed", 'has updated search term to "none status:closed"');
  });
});

QUnit.test("update post time through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced-btn');
  fillIn('#search-post-date', '2016-10-05');
  expandSelectBox('.search-advanced-options .select-box-kit#postTime');
  selectBoxSelectRow('after', { selector: '.search-advanced-options .select-box-kit#postTime' });
  fillIn('.search-advanced-options .select-box-kit#postTime', 'after');

  andThen(() => {
    assert.ok(exists(selectBox('.search-advanced-options .select-box-kit#postTime').rowByName("after").el), 'has "after" populated');
    assert.equal(find('.search-advanced-options #search-post-date').val(), "2016-10-05", 'has "2016-10-05" populated');
    assert.equal(find('.search input.full-page-search').val(), "none after:2016-10-05", 'has updated search term to "none after:2016-10-05"');
  });
});

QUnit.test("update min post count through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced-btn');
  fillIn('#search-min-post-count', '5');

  andThen(() => {
    assert.equal(find('.search-advanced-options #search-min-post-count').val(), "5", 'has "5" populated');
    assert.equal(find('.search input.full-page-search').val(), "none min_post_count:5", 'has updated search term to "none min_post_count:5"');
  });
});

QUnit.test("validate advanced search when initially empty", assert => {
  visit("/search?expanded=true");
  click('.search-advanced-options .in-likes');

  andThen(() => {
    assert.ok(exists('.search-advanced-options .in-likes:checked'), 'has "I liked" populated');
    assert.equal(find('.search input.full-page-search').val(), "in:likes", 'has updated search term to "in:likes"');
  });
});
