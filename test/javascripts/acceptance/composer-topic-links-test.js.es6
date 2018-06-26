import { acceptance, replaceCurrentUser } from "helpers/qunit-helpers";

acceptance("Composer topic featured links", {
  loggedIn: true,
  settings: {
    topic_featured_link_enabled: true,
    max_topic_title_length: 80,
    enable_markdown_linkify: true
  }
});

QUnit.test("onebox with title", assert => {
  visit("/");
  click("#create-topic");
  fillIn("#reply-title", "http://www.example.com/has-title.html");
  andThen(() => {
    assert.ok(
      find(".d-editor-preview")
        .html()
        .trim()
        .indexOf("onebox") > 0,
      "it pastes the link into the body and previews it"
    );
    assert.ok(
      exists(".d-editor-textarea-wrapper .popup-tip.good"),
      "the body is now good"
    );
    assert.equal(
      find(".title-input input").val(),
      "An interesting article",
      "title is from the oneboxed article"
    );
  });
});

QUnit.test("onebox result doesn't include a title", assert => {
  visit("/");
  click("#create-topic");
  fillIn("#reply-title", "http://www.example.com/no-title.html");
  andThen(() => {
    assert.ok(
      find(".d-editor-preview")
        .html()
        .trim()
        .indexOf("onebox") > 0,
      "it pastes the link into the body and previews it"
    );
    assert.ok(
      exists(".d-editor-textarea-wrapper .popup-tip.good"),
      "the body is now good"
    );
    assert.equal(
      find(".title-input input").val(),
      "http://www.example.com/no-title.html",
      "title is unchanged"
    );
  });
});

QUnit.test("no onebox result", assert => {
  visit("/");
  click("#create-topic");
  fillIn("#reply-title", "http://www.example.com/nope-onebox.html");
  andThen(() => {
    assert.ok(
      find(".d-editor-preview")
        .html()
        .trim()
        .indexOf("onebox") > 0,
      "it pastes the link into the body and previews it"
    );
    assert.ok(
      exists(".d-editor-textarea-wrapper .popup-tip.good"),
      "link is pasted into body"
    );
    assert.equal(
      find(".title-input input").val(),
      "http://www.example.com/nope-onebox.html",
      "title is unchanged"
    );
  });
});

QUnit.test("ignore internal links", assert => {
  visit("/");
  click("#create-topic");
  const title = "http://" + window.location.hostname + "/internal-page.html";
  fillIn("#reply-title", title);
  andThen(() => {
    assert.equal(
      find(".d-editor-preview")
        .html()
        .trim()
        .indexOf("onebox"),
      -1,
      "onebox preview doesn't show"
    );
    assert.equal(
      find(".d-editor-input").val().length,
      0,
      "link isn't put into the post"
    );
    assert.equal(find(".title-input input").val(), title, "title is unchanged");
  });
});

QUnit.test("link is longer than max title length", assert => {
  visit("/");
  click("#create-topic");
  fillIn(
    "#reply-title",
    "http://www.example.com/has-title-and-a-url-that-is-more-than-80-characters-because-thats-good-for-seo-i-guess.html"
  );
  andThen(() => {
    assert.ok(
      find(".d-editor-preview")
        .html()
        .trim()
        .indexOf("onebox") > 0,
      "it pastes the link into the body and previews it"
    );
    assert.ok(
      exists(".d-editor-textarea-wrapper .popup-tip.good"),
      "the body is now good"
    );
    assert.equal(
      find(".title-input input").val(),
      "An interesting article",
      "title is from the oneboxed article"
    );
  });
});

QUnit.test("onebox with title but extra words in title field", assert => {
  visit("/");
  click("#create-topic");
  fillIn("#reply-title", "http://www.example.com/has-title.html test");
  andThen(() => {
    assert.equal(
      find(".d-editor-preview")
        .html()
        .trim()
        .indexOf("onebox"),
      -1,
      "onebox preview doesn't show"
    );
    assert.equal(
      find(".d-editor-input").val().length,
      0,
      "link isn't put into the post"
    );
    assert.equal(
      find(".title-input input").val(),
      "http://www.example.com/has-title.html test",
      "title is unchanged"
    );
  });
});

acceptance("Composer topic featured links when uncategorized is not allowed", {
  loggedIn: true,
  settings: {
    topic_featured_link_enabled: true,
    max_topic_title_length: 80,
    enable_markdown_linkify: true,
    allow_uncategorized_topics: false
  }
});

QUnit.test("Pasting a link enables the text input area", assert => {
  replaceCurrentUser({ admin: false, staff: false, trust_level: 1 });

  visit("/");
  click("#create-topic");
  andThen(() => {
    assert.ok(
      find(".d-editor-textarea-wrapper.disabled").length,
      "textarea is disabled"
    );
  });
  fillIn("#reply-title", "http://www.example.com/has-title.html");
  andThen(() => {
    assert.ok(
      find(".d-editor-preview")
        .html()
        .trim()
        .indexOf("onebox") > 0,
      "it pastes the link into the body and previews it"
    );
    assert.ok(
      exists(".d-editor-textarea-wrapper .popup-tip.good"),
      "the body is now good"
    );
    assert.equal(
      find(".title-input input").val(),
      "An interesting article",
      "title is from the oneboxed article"
    );
    assert.ok(
      find(".d-editor-textarea-wrapper.disabled").length === 0,
      "textarea is enabled"
    );
  });
});
