import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic", { loggedIn: true });

test("Share Popup", () => {
  visit("/t/internationalization-localization/280");
  andThen(() => {
    ok(!exists('#share-link.visible'), 'it is not visible');
  });

  click("button[data-share-url]");
  andThen(() => {
    ok(exists('#share-link.visible'), 'it shows the popup');
  });

  click('#share-link .close-share');
  andThen(() => {
    ok(!exists('#share-link.visible'), 'it closes the popup');
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
