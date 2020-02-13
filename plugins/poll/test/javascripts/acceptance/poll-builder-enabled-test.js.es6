import selectKit from "helpers/select-kit-helper";
import { acceptance, updateCurrentUser } from "helpers/qunit-helpers";
import { displayPollBuilderButton } from "discourse/plugins/poll/helpers/display-poll-builder-button";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";

acceptance("Poll Builder - polls are enabled", {
  loggedIn: true,
  settings: {
    poll_enabled: true,
    poll_minimum_trust_level_to_create: 1
  },
  beforeEach() {
    clearPopupMenuOptionsCallback();
  }
});

test("regular user - sufficient trust level", async assert => {
  updateCurrentUser({ moderator: false, admin: false, trust_level: 1 });

  await displayPollBuilderButton();

  assert.ok(
    exists(".select-kit-row[title='Build Poll']"),
    "it shows the builder button"
  );
});

test("regular user - insufficient trust level", async assert => {
  updateCurrentUser({ moderator: false, admin: false, trust_level: 0 });

  await displayPollBuilderButton();

  assert.ok(
    !exists(".select-kit-row[title='Build Poll']"),
    "it hides the builder button"
  );
});

test("staff - with insufficient trust level", async assert => {
  updateCurrentUser({ moderator: true, trust_level: 0 });

  await displayPollBuilderButton();

  assert.ok(
    exists(".select-kit-row[title='Build Poll']"),
    "it shows the builder button"
  );
});

test("poll preview", async assert => {
  await displayPollBuilderButton();

  const popupMenu = selectKit(".toolbar-popup-menu-options");
  await popupMenu.selectRowByValue("showPollBuilder");

  await fillIn(".poll-textarea textarea", "First option\nSecond option");

  assert.equal(find(".d-editor-preview li:first-child").text(), "First option");
  assert.equal(find(".d-editor-preview li:last-child").text(), "Second option");
});
