import { acceptance } from "helpers/qunit-helpers";

acceptance("Composer", { loggedIn: true });

test("Tests the Composer controls", () => {
  visit("/");
  andThen(() => {
    ok(exists('#create-topic'), 'the create button is visible');
  });

  click('#create-topic');
  andThen(() => {
    ok(exists('.d-editor-input'), 'the composer input is visible');
    ok(exists('.title-input .popup-tip.bad.hide'), 'title errors are hidden by default');
    ok(exists('.d-editor-textarea-wrapper .popup-tip.bad.hide'), 'body errors are hidden by default');
  });

  click('a.toggle-preview');
  andThen(() => {
    ok(!exists('.d-editor-preview:visible'), "clicking the toggle hides the preview");
  });

  click('a.toggle-preview');
  andThen(() => {
    ok(exists('.d-editor-preview:visible'), "clicking the toggle shows the preview again");
  });

  click('#reply-control button.create');
  andThen(() => {
    ok(!exists('.title-input .popup-tip.bad.hide'), 'it shows the empty title error');
    ok(!exists('.d-editor-wrapper .popup-tip.bad.hide'), 'it shows the empty body error');
  });

  fillIn('#reply-title', "this is my new topic title");
  andThen(() => {
    ok(exists('.title-input .popup-tip.good'), 'the title is now good');
  });

  fillIn('.d-editor-input', "this is the *content* of a post");
  andThen(() => {
    equal(find('.d-editor-preview').html().trim(), "<p>this is the <em>content</em> of a post</p>", "it previews content");
    ok(exists('.d-editor-textarea-wrapper .popup-tip.good'), 'the body is now good');
  });

  andThen(() => {
    const textarea = find('#reply-control .d-editor-input')[0];
    textarea.selectionStart = textarea.value.length;
    textarea.selectionEnd = textarea.value.length;

    // Testing keyboard events is tough!
    const mac = /Mac|iPod|iPhone|iPad/.test(navigator.platform);
    const event = document.createEvent('Event');
    event.initEvent('keydown', true, true);
    event[mac ? 'metaKey' : 'ctrlKey'] = true;
    event.keyCode = 66;

    textarea.dispatchEvent(event);
  });

  andThen(() => {
    const example = I18n.t(`composer.bold_text`);
    equal(find('#reply-control .d-editor-input').val().trim(),
               `this is the *content* of a post**${example}**`,
               "it supports keyboard shortcuts");
  });

  click('#reply-control a.cancel');
  andThen(() => {
    ok(exists('.bootbox.modal'), 'it pops up a confirmation dialog');
  });

  click('.modal-footer a:eq(1)');
  andThen(() => {
    ok(!exists('.bootbox.modal'), 'the confirmation can be cancelled');
  });

});

test("Create a topic with server side errors", () => {
  visit("/");
  click('#create-topic');
  fillIn('#reply-title', "this title triggers an error");
  fillIn('.d-editor-input', "this is the *content* of a post");
  click('#reply-control button.create');
  andThen(() => {
    ok(exists('.bootbox.modal'), 'it pops up an error message');
  });
  click('.bootbox.modal a.btn-primary');
  andThen(() => {
    ok(!exists('.bootbox.modal'), 'it dismisses the error');
    ok(exists('.d-editor-input'), 'the composer input is visible');
  });
});

test("Create a Topic", () => {
  visit("/");
  click('#create-topic');
  fillIn('#reply-title', "Internationalization Localization");
  fillIn('.d-editor-input', "this is the *content* of a new topic post");
  click('#reply-control button.create');
  andThen(() => {
    equal(currentURL(), "/t/internationalization-localization/280", "it transitions to the newly created topic URL");
  });
});

test("Create an enqueued Topic", () => {
  visit("/");
  click('#create-topic');
  fillIn('#reply-title', "Internationalization Localization");
  fillIn('.d-editor-input', "enqueue this content please");
  click('#reply-control button.create');
  andThen(() => {
    ok(visible('#discourse-modal'), 'it pops up a modal');
    equal(currentURL(), "/", "it doesn't change routes");
  });

  click('.modal-footer button');
  andThen(() => {
    ok(invisible('#discourse-modal'), 'the modal can be dismissed');
  });
});


test("Create a Reply", () => {
  visit("/t/internationalization-localization/280");

  andThen(() => {
    ok(!exists('article[data-post-id=12345]'), 'the post is not in the DOM');
  });

  click('#topic-footer-buttons .btn.create');
  andThen(() => {
    ok(exists('.d-editor-input'), 'the composer input is visible');
    ok(!exists('#reply-title'), 'there is no title since this is a reply');
  });

  fillIn('.d-editor-input', 'this is the content of my reply');
  click('#reply-control button.create');
  andThen(() => {
    equal(find('.cooked:last p').text(), 'this is the content of my reply');
  });
});

test("Posting on a different topic", (assert) => {
  visit("/t/internationalization-localization/280");
  click('#topic-footer-buttons .btn.create');
  fillIn('.d-editor-input', 'this is the content for a different topic');

  visit("/t/1-3-0beta9-no-rate-limit-popups/28830");
  andThen(function() {
    assert.equal(currentURL(), "/t/1-3-0beta9-no-rate-limit-popups/28830");
  });
  click('#reply-control button.create');
  andThen(function() {
    assert.ok(visible('.reply-where-modal'), 'it pops up a modal');
  });

  click('.btn-reply-here');
  andThen(() => {
    assert.equal(find('.cooked:last p').text(), 'this is the content for a different topic');
  });
});


test("Create an enqueued Reply", () => {
  visit("/t/internationalization-localization/280");

  click('#topic-footer-buttons .btn.create');
  andThen(() => {
    ok(exists('.d-editor-input'), 'the composer input is visible');
    ok(!exists('#reply-title'), 'there is no title since this is a reply');
  });

  fillIn('.d-editor-input', 'enqueue this content please');
  click('#reply-control button.create');
  andThen(() => {
    ok(find('.cooked:last p').text() !== 'enqueue this content please', "it doesn't insert the post");
  });

  andThen(() => {
    ok(visible('#discourse-modal'), 'it pops up a modal');
  });

  click('.modal-footer button');
  andThen(() => {
    ok(invisible('#discourse-modal'), 'the modal can be dismissed');
  });
});

test("Edit the first post", () => {
  visit("/t/internationalization-localization/280");

  ok(!exists('.topic-post:eq(0) .post-info.edits'), 'it has no edits icon at first');

  click('.topic-post:eq(0) button.show-more-actions');
  click('.topic-post:eq(0) button.edit');
  andThen(() => {
    equal(find('.d-editor-input').val().indexOf('Any plans to support'), 0, 'it populates the input with the post text');
  });

  fillIn('.d-editor-input', "This is the new text for the post");
  fillIn('#reply-title', "This is the new text for the title");
  click('#reply-control button.create');
  andThen(() => {
    ok(!exists('.d-editor-input'), 'it closes the composer');
    ok(exists('.topic-post:eq(0) .post-info.edits'), 'it has the edits icon');
    ok(find('#topic-title h1').text().indexOf('This is the new text for the title') !== -1, 'it shows the new title');
    ok(find('.topic-post:eq(0) .cooked').text().indexOf('This is the new text for the post') !== -1, 'it updates the post');
  });
});

test("Composer can switch between edits", () => {
  visit("/t/this-is-a-test-topic/9");

  click('.topic-post:eq(0) button.edit');
  andThen(() => {
    equal(find('.d-editor-input').val().indexOf('This is the first post.'), 0, 'it populates the input with the post text');
  });
  click('.topic-post:eq(1) button.edit');
  andThen(() => {
    equal(find('.d-editor-input').val().indexOf('This is the second post.'), 0, 'it populates the input with the post text');
  });
});

test("Composer with dirty edit can toggle to another edit", () => {
  visit("/t/this-is-a-test-topic/9");

  click('.topic-post:eq(0) button.edit');
  fillIn('.d-editor-input', 'This is a dirty reply');
  click('.topic-post:eq(1) button.edit');
  andThen(() => {
    ok(exists('.bootbox.modal'), 'it pops up a confirmation dialog');
  });
  click('.modal-footer a:eq(0)');
  andThen(() => {
    equal(find('.d-editor-input').val().indexOf('This is the second post.'), 0, 'it populates the input with the post text');
  });
});

test("Composer can toggle between edit and reply", () => {
  visit("/t/this-is-a-test-topic/9");

  click('.topic-post:eq(0) button.edit');
  andThen(() => {
    equal(find('.d-editor-input').val().indexOf('This is the first post.'), 0, 'it populates the input with the post text');
  });
  click('.topic-post:eq(0) button.reply');
  andThen(() => {
    equal(find('.d-editor-input').val(), "", 'it clears the input');
  });
  click('.topic-post:eq(0) button.edit');
  andThen(() => {
    equal(find('.d-editor-input').val().indexOf('This is the first post.'), 0, 'it populates the input with the post text');
  });
});

test("Composer with dirty reply can toggle to edit", () => {
  visit("/t/this-is-a-test-topic/9");

  click('.topic-post:eq(0) button.reply');
  fillIn('.d-editor-input', 'This is a dirty reply');
  click('.topic-post:eq(0) button.edit');
  andThen(() => {
    ok(exists('.bootbox.modal'), 'it pops up a confirmation dialog');
  });
  click('.modal-footer a:eq(0)');
  andThen(() => {
    equal(find('.d-editor-input').val().indexOf('This is the first post.'), 0, 'it populates the input with the post text');
  });
});

test("Composer draft with dirty reply can toggle to edit", () => {
  visit("/t/this-is-a-test-topic/9");

  click('.topic-post:eq(0) button.reply');
  fillIn('.d-editor-input', 'This is a dirty reply');
  click('.toggler');
  click('.topic-post:eq(0) button.edit');
  andThen(() => {
    ok(exists('.bootbox.modal'), 'it pops up a confirmation dialog');
  });
  click('.modal-footer a:eq(0)');
  andThen(() => {
    equal(find('.d-editor-input').val().indexOf('This is the first post.'), 0, 'it populates the input with the post text');
  });
});
