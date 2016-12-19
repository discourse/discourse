import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic", { loggedIn: true });

test("Share Popup", () => {
  visit("/t/internationalization-localization/280");
  andThen(() => {
    ok(!exists('#share-link.visible'), 'it is not visible');
  });

  click("[data-share-url]:eq(0)");
  andThen(() => {
    ok(exists('#share-link.visible'), 'it shows the popup');
  });

  click('#share-link .close-share');
  andThen(() => {
    ok(!exists('#share-link.visible'), 'it closes the popup');
  });
});

test("Showing and hiding the edit controls", () => {
  visit("/t/internationalization-localization/280");

  click('#topic-title .fa-pencil');

  andThen(() => {
    ok(exists('#edit-title'), 'it shows the editing controls');
  });

  fillIn('#edit-title', 'this is the new title');
  click('#topic-title .cancel-edit');
  andThen(() => {
    ok(!exists('#edit-title'), 'it hides the editing controls');
  });
});

test("Updating the topic title and category", () => {
  visit("/t/internationalization-localization/280");
  click('#topic-title .fa-pencil');

  fillIn('#edit-title', 'this is the new title');
  selectDropdown('.category-combobox', 4);

  click('#topic-title .submit-edit');

  andThen(() => {
    equal(find('#topic-title .badge-category').text(), 'faq', 'it displays the new category');
    equal(find('.fancy-title').text().trim(), 'this is the new title', 'it displays the new title');
  });
});

test("Reply as New Topic", () => {
  visit("/t/internationalization-localization/280");
  click("[data-share-url]:eq(0)");
  click(".reply-as-new-topic a");
  andThen(() => {
    ok(exists('.d-editor-input'), 'the composer input is visible');
    equal(find('.d-editor-input').val().trim(),
          "Continuing the discussion from [Internationalization / localization](http://localhost:4000/t/internationalization-localization/280):",
          "it fills composer with 'continuing the discussion from' string");
    equal(find('#select2-chosen-1').text().trim(), "feature", "it fills category selector with category");
  });
});
