import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic", { loggedIn: true });

QUnit.test("Share Popup", assert => {
  visit("/t/internationalization-localization/280");
  andThen(() => {
    assert.ok(!exists("#share-link.visible"), "it is not visible");
  });

  click("button[data-share-url]");
  andThen(() => {
    assert.ok(exists("#share-link.visible"), "it shows the popup");
  });

  click("#share-link .close-share");
  andThen(() => {
    assert.ok(!exists("#share-link.visible"), "it closes the popup");
  });

  // TODO tgxworld This fails on Travis but we need to push the security fix out
  // first.
  // click('#topic-footer-buttons .btn.create');
  // fillIn('.d-editor-input', '<h2><div data-share-url="something">Click</button><h2>');
  //
  // click('#reply-control .btn.create');
  // click('h2 div[data-share-url]');
  //
  // andThen(() => {
  //   ok(!exists('#share-link.visible'), 'it does not show the popup');
  // });
});

QUnit.test("Showing and hiding the edit controls", assert => {
  visit("/t/internationalization-localization/280");

  click("#topic-title .d-icon-pencil");

  andThen(() => {
    assert.ok(exists("#edit-title"), "it shows the editing controls");
    assert.ok(
      !exists(".title-wrapper .remove-featured-link"),
      "link to remove featured link is not shown"
    );
  });

  fillIn("#edit-title", "this is the new title");
  click("#topic-title .cancel-edit");
  andThen(() => {
    assert.ok(!exists("#edit-title"), "it hides the editing controls");
  });
});

QUnit.test("Updating the topic title and category", assert => {
  const categoryChooser = selectKit(".title-wrapper .category-chooser");

  visit("/t/internationalization-localization/280");

  click("#topic-title .d-icon-pencil");
  fillIn("#edit-title", "this is the new title");
  categoryChooser.expand().selectRowByValue(4);
  click("#topic-title .submit-edit");

  andThen(() => {
    assert.equal(
      find("#topic-title .badge-category").text(),
      "faq",
      "it displays the new category"
    );
    assert.equal(
      find(".fancy-title")
        .text()
        .trim(),
      "this is the new title",
      "it displays the new title"
    );
  });
});

QUnit.test("Marking a topic as wiki", assert => {
  // prettier-ignore
  server.put("/posts/398/wiki", () => { // eslint-disable-line no-undef
    return [200, { "Content-Type": "application/json" }, {}];
  });

  visit("/t/internationalization-localization/280");

  andThen(() => {
    assert.ok(find("a.wiki").length === 0, "it does not show the wiki icon");
  });

  click(".topic-post:eq(0) button.show-more-actions");
  click(".topic-post:eq(0) button.show-post-admin-menu");
  click(".btn.wiki");

  andThen(() => {
    assert.ok(find("a.wiki").length === 1, "it shows the wiki icon");
  });
});

QUnit.test("Reply as new topic", assert => {
  visit("/t/internationalization-localization/280");
  click("button.share:eq(0)");
  click(".reply-as-new-topic a");

  andThen(() => {
    assert.ok(exists(".d-editor-input"), "the composer input is visible");

    assert.equal(
      find(".d-editor-input")
        .val()
        .trim(),
      `Continuing the discussion from [Internationalization / localization](${
        window.location.origin
      }/t/internationalization-localization/280):`,
      "it fills composer with the ring string"
    );
    assert.equal(
      selectKit(".category-chooser")
        .header()
        .value(),
      "2",
      "it fills category selector with the right category"
    );
  });
});

QUnit.test("Reply as new message", assert => {
  visit("/t/pm-for-testing/12");
  click("button.share:eq(0)");
  click(".reply-as-new-topic a");

  andThen(() => {
    assert.ok(exists(".d-editor-input"), "the composer input is visible");

    assert.equal(
      find(".d-editor-input")
        .val()
        .trim(),
      `Continuing the discussion from [PM for testing](${
        window.location.origin
      }/t/pm-for-testing/12):`,
      "it fills composer with the ring string"
    );

    const targets = find(".item span", ".composer-fields");

    assert.equal(
      $(targets[0]).text(),
      "someguy",
      "it fills up the composer with the right user to start the PM to"
    );

    assert.equal(
      $(targets[1]).text(),
      "test",
      "it fills up the composer with the right user to start the PM to"
    );

    assert.equal(
      $(targets[2]).text(),
      "Group",
      "it fills up the composer with the right group to start the PM to"
    );
  });
});

QUnit.test("Visit topic routes", assert => {
  visit("/t/12");

  andThen(() => {
    assert.equal(
      find(".fancy-title")
        .text()
        .trim(),
      "PM for testing",
      "it routes to the right topic"
    );
  });

  visit("/t/280/20");

  andThen(() => {
    assert.equal(
      find(".fancy-title")
        .text()
        .trim(),
      "Internationalization / localization",
      "it routes to the right topic"
    );
  });
});

QUnit.test("Updating the topic title with emojis", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-title .d-icon-pencil");

  fillIn("#edit-title", "emojis title :bike: :blonde_woman:t6:");

  click("#topic-title .submit-edit");

  andThen(() => {
    assert.equal(
      find(".fancy-title")
        .html()
        .trim(),
      'emojis title <img src="/images/emoji/emoji_one/bike.png?v=5" title="bike" alt="bike" class="emoji"> <img src="/images/emoji/emoji_one/blonde_woman/6.png?v=5" title="blonde_woman:t6" alt="blonde_woman:t6" class="emoji">',
      "it displays the new title with emojis"
    );
  });
});

acceptance("Topic featured links", {
  loggedIn: true,
  settings: {
    topic_featured_link_enabled: true,
    max_topic_title_length: 80
  }
});

QUnit.test("remove featured link", assert => {
  visit("/t/299/1");
  andThen(() => {
    assert.ok(
      exists(".title-wrapper .topic-featured-link"),
      "link is shown with topic title"
    );
  });

  click(".title-wrapper .edit-topic");
  andThen(() => {
    assert.ok(
      exists(".title-wrapper .remove-featured-link"),
      "link to remove featured link"
    );
  });

  // this test only works in a browser:
  // click('.title-wrapper .remove-featured-link');
  // click('.title-wrapper .submit-edit');
  // andThen(() => {
  //   assert.ok(!exists('.title-wrapper .topic-featured-link'), 'link is gone');
  // });
});
