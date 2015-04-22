import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic", { loggedIn: true });

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
