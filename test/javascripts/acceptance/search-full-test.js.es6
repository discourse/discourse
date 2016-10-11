import { acceptance, waitFor } from "helpers/qunit-helpers";
acceptance("Search - Full Page", {
  settings: {tagging_enabled: true},
  setup() {
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

    server.get('/users/search/users', () => { //eslint-disable-line
      return response({users: [{username: "admin", name: "admin",
        avatar_template: "/letter_avatar_proxy/v2/letter/a/3ec8ea/{size}.png"}]});
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

test("perform various searches", assert => {
  visit("/search");

  andThen(() => {
    assert.ok(find('input.search').length > 0);
    assert.ok(find('.fps-topic').length === 0);
  });

  fillIn('.search input.full-page-search', 'none');
  click('.search .btn-primary');

  andThen(() => assert.ok(find('.fps-topic').length === 0), 'has no results');

  fillIn('.search input.full-page-search', 'posts');
  click('.search .btn-primary');

  andThen(() => assert.ok(find('.fps-topic').length === 1, 'has one post'));
});

test("open advanced search", assert => {
  visit("/search");

  andThen(() => assert.ok(exists('.search .search-advanced'), 'shows advanced search panel'));

  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced h3.panel-title');

  andThen(() => assert.ok(visible('.search-advanced .search-options'), '"search-options" is visible'));
});

test("validate population of advanced search", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'test user:admin #bug group:moderators badge:Reader tags:monkey in:likes status:open after:5 posts_count:10');
  click('.search-advanced h3.panel-title');

  andThen(() => {
    assert.ok(exists('.search-options span:contains("admin")'), 'has "admin" pre-populated');
    assert.ok(exists('.search-options .category-combobox .select2-choice .select2-chosen:contains("bug")'), 'has "bug" pre-populated');
    assert.ok(exists('.search-options span:contains("moderators")'), 'has "moderators" pre-populated');
    assert.ok(exists('.search-options span:contains("Reader")'), 'has "Reader" pre-populated');
    assert.ok(exists('.search-options .tag-chooser .tag-monkey'), 'has "monkey" pre-populated');
    assert.ok(exists('.search-options .combobox .select2-choice .select2-chosen:contains("I liked")'), 'has "I liked" pre-populated');
    assert.ok(exists('.search-options .combobox .select2-choice .select2-chosen:contains("are open")'), 'has "are open" pre-populated');
    assert.ok(exists('.search-options .combobox .select2-choice .select2-chosen:contains("after")'), 'has "after" pre-populated');
    assert.equal(find('.search-options #search-post-date').val(), "5", 'has "5" pre-populated');
    assert.equal(find('.search-options #search-posts-count').val(), "10", 'has "10" pre-populated');
  });
});

test("update username through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced h3.panel-title');
  fillIn('.search-options .user-selector', 'admin');
  click('.search-options .user-selector');
  keyEvent('.search-options .user-selector', 'keydown', 8);

  andThen(() => {
    waitFor(() => {
      assert.ok(visible('.search-options .autocomplete'), '"autocomplete" popup is visible');
      assert.ok(exists('.search-options .autocomplete ul li a span.username:contains("admin")'), '"autocomplete" popup has an entry for "admin"');

      click('.search-options .autocomplete ul li a:first');

      andThen(() => {
        assert.ok(exists('.search-options span:contains("admin")'), 'has "admin" pre-populated');
        assert.equal(find('.search input.full-page-search').val(), "none @admin", 'has updated search term to "none user:admin"');
      });
    });
  });
});

test("update category through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced h3.panel-title');
  selectDropdown('.search-options .category-combobox', 4);
  click('.search-options'); // need to click off the combobox for the search-term to get updated

  andThen(() => {
    assert.ok(exists('.search-options .category-combobox .select2-choice .select2-chosen:contains("faq")'), 'has "faq" populated');
    assert.equal(find('.search input.full-page-search').val(), "none #faq", 'has updated search term to "none #faq"');
  });
});

test("update group through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced h3.panel-title');
  fillIn('.search-options .group-selector', 'moderators');
  click('.search-options .group-selector');
  keyEvent('.search-options .group-selector', 'keydown', 8);

  andThen(() => {
    waitFor(() => {
      assert.ok(visible('.search-options .autocomplete'), '"autocomplete" popup is visible');
      assert.ok(exists('.search-options .autocomplete ul li a:contains("moderators")'), '"autocomplete" popup has an entry for "moderators"');

      click('.search-options .autocomplete ul li a:first');

      andThen(() => {
        assert.ok(exists('.search-options span:contains("moderators")'), 'has "moderators" pre-populated');
        assert.equal(find('.search input.full-page-search').val(), "none group:moderators", 'has updated search term to "none group:moderators"');
      });
    });
  });
});

test("update badges through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced h3.panel-title');
  fillIn('.search-options .badge-names', 'Reader');
  click('.search-options .badge-names');
  keyEvent('.search-options .badge-names', 'keydown', 8);

  andThen(() => {
    waitFor(() => {
      assert.ok(visible('.search-options .autocomplete'), '"autocomplete" popup is visible');
      assert.ok(exists('.search-options .autocomplete ul li a:contains("Reader")'), '"autocomplete" popup has an entry for "Reader"');

      click('.search-options .autocomplete ul li a:first');

      andThen(() => {
        assert.ok(exists('.search-options span:contains("Reader")'), 'has "Reader" pre-populated');
        assert.equal(find('.search input.full-page-search').val(), "none badge:Reader", 'has updated search term to "none badge:Reader"');
      });
    });
  });
});

// test("update tags through advanced search ui", assert => {
//   visit("/search");
//   fillIn('.search input.full-page-search', 'none');
//   click('.search-advanced h3.panel-title');
//
//   keyEvent('.search-options .tag-chooser input.select2-input', 'keydown', 110);
//   fillIn('.search-options .tag-chooser input.select2-input', 'monkey');
//   keyEvent('.search-options .tag-chooser input.select2-input', 'keyup', 110);
//
//   andThen(() => {
//     waitFor(() => {
//       click('li.select2-result-selectable:first');
//       andThen(() => {
//         assert.ok(exists('.search-options .tag-chooser .tag-monkey'), 'has "monkey" pre-populated');
//         assert.equal(find('.search input.full-page-search').val(), "none tags:monkey", 'has updated search term to "none tags:monkey"');
//       });
//     });
//   });
// });

test("update in filter through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced h3.panel-title');
  selectDropdown('.search-options #s2id_in', 'likes');
  fillIn('.search-options #in', 'likes');

  andThen(() => {
    assert.ok(exists('.search-options #s2id_in .select2-choice .select2-chosen:contains("I liked")'), 'has "I liked" populated');
    assert.equal(find('.search input.full-page-search').val(), "none in:likes", 'has updated search term to "none in:likes"');
  });
});

test("update status through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced h3.panel-title');
  selectDropdown('.search-options #s2id_status', 'closed');
  fillIn('.search-options #status', 'closed');

  andThen(() => {
    assert.ok(exists('.search-options #s2id_status .select2-choice .select2-chosen:contains("are closed")'), 'has "are closed" populated');
    assert.equal(find('.search input.full-page-search').val(), "none status:closed", 'has updated search term to "none status:closed"');
  });
});

test("update post time through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced h3.panel-title');
  fillIn('#search-post-date', '5');
  selectDropdown('.search-options #s2id_postTime', 'after');
  fillIn('.search-options #postTime', 'after');

  andThen(() => {
    assert.ok(exists('.search-options #s2id_postTime .select2-choice .select2-chosen:contains("after")'), 'has "after" populated');
    assert.equal(find('.search-options #search-post-date').val(), "5", 'has "5" populated');
    assert.equal(find('.search input.full-page-search').val(), "none after:5", 'has updated search term to "none after:5"');
  });
});

test("update posts count through advanced search ui", assert => {
  visit("/search");
  fillIn('.search input.full-page-search', 'none');
  click('.search-advanced h3.panel-title');
  fillIn('#search-posts-count', '5');

  andThen(() => {
    assert.equal(find('.search-options #search-posts-count').val(), "5", 'has "5" populated');
    assert.equal(find('.search input.full-page-search').val(), "none posts_count:5", 'has updated search term to "none posts_count:5"');
  });
});
