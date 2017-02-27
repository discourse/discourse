import { acceptance } from "helpers/qunit-helpers";

acceptance("Composer topic featured links", {
  loggedIn: true,
  settings: {
    topic_featured_link_enabled: true
  }
});


test("onebox with title", () => {
  visit("/");
  click('#create-topic');
  fillIn('#reply-title', "http://www.example.com/has-title.html");
  andThen(() => {
    ok(find('.d-editor-preview').html().trim().indexOf('onebox') > 0, "it pastes the link into the body and previews it");
    ok(exists('.d-editor-textarea-wrapper .popup-tip.good'), 'the body is now good');
    equal(find('.title-input input').val(), "An interesting article", "title is from the oneboxed article");
  });
});

test("onebox result doesn't include a title", () => {
  visit("/");
  click('#create-topic');
  fillIn('#reply-title', 'http://www.example.com/no-title.html');
  andThen(() => {
    ok(find('.d-editor-preview').html().trim().indexOf('onebox') > 0, "it pastes the link into the body and previews it");
    ok(exists('.d-editor-textarea-wrapper .popup-tip.good'), 'the body is now good');
    equal(find('.title-input input').val(), "http://www.example.com/no-title.html", "title is unchanged");
  });
});

test("no onebox result", () => {
  visit("/");
  click('#create-topic');
  fillIn('#reply-title', "http://www.example.com/nope-onebox.html");
  andThen(() => {
    ok(find('.d-editor-preview').html().trim().indexOf('onebox') > 0, "it pastes the link into the body and previews it");
    ok(exists('.d-editor-textarea-wrapper .popup-tip.good'), 'link is pasted into body');
    equal(find('.title-input input').val(), "http://www.example.com/nope-onebox.html", "title is unchanged");
  });
});

test("ignore internal links", () => {
  visit("/");
  click('#create-topic');
  const title = "http://" + window.location.hostname + "/internal-page.html";
  fillIn('#reply-title', title);
  andThen(() => {
    equal(find('.d-editor-preview').html().trim().indexOf('onebox'), -1, "onebox preview doesn't show");
    equal(find('.d-editor-input').val().length, 0, "link isn't put into the post");
    equal(find('.title-input input').val(), title, "title is unchanged");
  });
});
