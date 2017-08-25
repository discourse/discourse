import { acceptance } from "helpers/qunit-helpers";

acceptance('Details Button', { loggedIn: true });

function findTextarea() {
  return find(".d-editor-input")[0];
}

test('details button', (assert) => {
  visit("/");

  click('#create-topic');
  click('button.options');
  click('.popup-menu .d-icon-caret-right');

  andThen(() => {
    assert.equal(
      find(".d-editor-input").val(),
      `\n[details="${I18n.t("composer.details_title")}"]\n${I18n.t("composer.details_text")}\n[/details]\n`,
      'it should contain the right output'
    );
  });

  fillIn('.d-editor-input', "This is my title");

  andThen(() => {
    const textarea = findTextarea();
    textarea.selectionStart = 0;
    textarea.selectionEnd = textarea.value.length;
  });

  click('button.options');
  click('.popup-menu .d-icon-caret-right');

  andThen(() => {
    assert.equal(
      find(".d-editor-input").val(),
      `\n[details="${I18n.t("composer.details_title")}"]\nThis is my title\n[/details]\n`,
      'it should contain the right selected output'
    );

    const textarea = findTextarea();
    assert.equal(textarea.selectionStart, 21, 'it should start highlighting at the right position');
    assert.equal(textarea.selectionEnd, 37, 'it should end highlighting at the right position');
  });

  fillIn('.d-editor-input', "Before some text in between After");

  andThen(() => {
    const textarea = findTextarea();
    textarea.selectionStart = 7;
    textarea.selectionEnd = 28;
  });

  click('button.options');
  click('.popup-menu .d-icon-caret-right');

  andThen(() => {
    assert.equal(
      find(".d-editor-input").val(),
      `Before \n[details="${I18n.t("composer.details_title")}"]\nsome text in between\n[/details]\n After`,
      'it should contain the right output'
    );

    const textarea = findTextarea();
    assert.equal(textarea.selectionStart, 28, 'it should start highlighting at the right position');
    assert.equal(textarea.selectionEnd, 48, 'it should end highlighting at the right position');
  });

  fillIn('.d-editor-input', "Before \nsome text in between\n After");

  andThen(() => {
    const textarea = findTextarea();
    textarea.selectionStart = 8;
    textarea.selectionEnd = 29;
  });

  click('button.options');
  click('.popup-menu .d-icon-caret-right');

  andThen(() => {
    assert.equal(
      find(".d-editor-input").val(),
      `Before \n\n[details="${I18n.t("composer.details_title")}"]\nsome text in between\n[/details]\n\n After`,
      'it should contain the right output'
    );

    const textarea = findTextarea();
    assert.equal(textarea.selectionStart, 29, 'it should start highlighting at the right position');
    assert.equal(textarea.selectionEnd, 49, 'it should end highlighting at the right position');
  });
});
