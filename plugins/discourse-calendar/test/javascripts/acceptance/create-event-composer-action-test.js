import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Site from "discourse/models/site";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

const _mutatedCategoryIds = new Set();

function markCategoryAsEvents(categoryId) {
  const category = Site.current().categories.find((c) => c.id === categoryId);
  category.categoryTypes = {
    events: { id: "events", name: "Events", configuration_schema: {} },
  };
  _mutatedCategoryIds.add(categoryId);
}

acceptance("Create event composer action", function (needs) {
  needs.user({ can_create_discourse_post_event: true });
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    discourse_post_event_allowed_on_groups: "",
    discourse_post_event_allowed_custom_fields: "",
  });

  needs.hooks.afterEach(function () {
    _mutatedCategoryIds.forEach((id) => {
      const category = Site.current().categories.find((c) => c.id === id);
      if (category) {
        category.categoryTypes = {};
      }
    });
    _mutatedCategoryIds.clear();
  });

  test("entering an events-type category puts the composer in event mode", async function (assert) {
    markCategoryAsEvents(2);

    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert
      .dom(".d-editor-input")
      .hasValue(
        /^\[event start="[^"]+" end="[^"]+" status="public" timezone="[^"]+" reminders="[^"]+"\]\n\[\/event\]$/,
        "event bbcode skeleton is inserted"
      );
    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("discourse_post_event.composer.create_event_button"));
    assert
      .dom(".save-or-cancel button.create .d-icon-calendar-day")
      .exists("submit button shows the calendar icon in event mode");
    assert
      .dom("#reply-title")
      .hasAttribute(
        "placeholder",
        i18n("discourse_post_event.composer.event_title_placeholder")
      );
  });

  test("non-events categories leave the composer in topic mode", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(1);

    assert.dom(".d-editor-input").hasNoValue();
    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("composer.create_topic"));
  });

  test("dropdown shows Create topic in event mode and Create event in topic mode (events-type only)", async function (assert) {
    markCategoryAsEvents(2);

    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    const composerActions = selectKit(".composer-actions");

    // Non-events category — neither plugin option appears
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(1);
    await composerActions.expand();
    assert
      .dom(`.composer-actions .select-kit-row[data-value="create_event"]`)
      .doesNotExist();
    assert
      .dom(
        `.composer-actions .select-kit-row[data-value="create_regular_topic"]`
      )
      .doesNotExist();
    await composerActions.collapse();

    // Events-type category — auto-enters event mode; Create topic switch-back appears
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await composerActions.expand();
    assert
      .dom(`.composer-actions .select-kit-row[data-value="create_event"]`)
      .doesNotExist();
    assert
      .dom(
        `.composer-actions .select-kit-row[data-value="create_regular_topic"]`
      )
      .exists();

    // Picking Create topic exits event mode and surfaces Create event
    await composerActions.selectRowByValue("create_regular_topic");
    assert.dom(".d-editor-input").hasNoValue("skeleton is cleared on exit");
    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("composer.create_topic"));

    await composerActions.expand();
    assert
      .dom(`.composer-actions .select-kit-row[data-value="create_event"]`)
      .exists();
    assert
      .dom(
        `.composer-actions .select-kit-row[data-value="create_regular_topic"]`
      )
      .doesNotExist();
  });

  test("switching from events-type to a regular category clears the unedited skeleton", async function (assert) {
    markCategoryAsEvents(2);

    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert.dom(".d-editor-input").hasValue(/^\[event /);
    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("discourse_post_event.composer.create_event_button"));

    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(1);

    assert
      .dom(".d-editor-input")
      .hasNoValue("unedited event skeleton is cleared");
    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("composer.create_topic"));
  });

  test("manually removing the event bbcode exits event mode", async function (assert) {
    markCategoryAsEvents(2);

    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("discourse_post_event.composer.create_event_button"));

    await fillIn(".d-editor-input", "just a regular topic body");

    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("composer.create_topic"));
    assert.notStrictEqual(
      document.querySelector("#reply-title").getAttribute("placeholder"),
      i18n("discourse_post_event.composer.event_title_placeholder"),
      "title placeholder is no longer the event one"
    );
  });

  test("manually adding an event block back re-enters event mode", async function (assert) {
    markCategoryAsEvents(2);

    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    // Exit by deleting the auto-inserted skeleton
    await fillIn(".d-editor-input", "");
    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("composer.create_topic"));

    // Now paste in an event block by hand
    await fillIn(
      ".d-editor-input",
      '[event start="2026-05-21 10:00" status="public" timezone="UTC"]\n[/event]'
    );

    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("discourse_post_event.composer.create_event_button"));
  });

  test("pasting an event block into a topic-mode reply enters event mode", async function (assert) {
    markCategoryAsEvents(2);

    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await fillIn(".d-editor-input", "");
    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("composer.create_topic"), "starts in topic mode");

    await fillIn(
      ".d-editor-input",
      '[event start="2026-06-15 10:00" status="public" timezone="UTC"]\n[/event]'
    );

    assert
      .dom(".save-or-cancel button.create")
      .hasText(
        i18n("discourse_post_event.composer.create_event_button"),
        "auto-enters event mode"
      );
  });

  test("switching to an events category with existing content does not auto-enter event mode", async function (assert) {
    markCategoryAsEvents(2);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(1);
    await fillIn(".d-editor-input", "draft I started in a regular category");

    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert
      .dom(".d-editor-input")
      .hasValue(
        "draft I started in a regular category",
        "existing reply is left untouched"
      );
    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("composer.create_topic"), "stays in topic mode");

    const composerActions = selectKit(".composer-actions");
    await composerActions.expand();
    assert
      .dom(`.composer-actions .select-kit-row[data-value="create_event"]`)
      .exists("Create event is still offered as an explicit opt-in");
  });

  test("an edited event block is preserved on category switch", async function (assert) {
    markCategoryAsEvents(2);

    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    const original = document.querySelector(".d-editor-input").value;
    const edited = original.replace(`status="public"`, `status="private"`);
    await fillIn(".d-editor-input", edited);

    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(1);

    assert
      .dom(".d-editor-input")
      .hasValue(edited, "user-edited content survives the switch");
  });
});

acceptance(
  "Create event composer action — user without create-event permission",
  function (needs) {
    needs.user({ can_create_discourse_post_event: false });
    needs.settings({
      calendar_enabled: true,
      discourse_post_event_enabled: true,
      discourse_post_event_allowed_on_groups: "",
      discourse_post_event_allowed_custom_fields: "",
    });

    needs.hooks.afterEach(function () {
      _mutatedCategoryIds.forEach((id) => {
        const category = Site.current().categories.find((c) => c.id === id);
        if (category) {
          category.categoryTypes = {};
        }
      });
      _mutatedCategoryIds.clear();
    });

    test("events-type category stays in regular topic mode", async function (assert) {
      markCategoryAsEvents(2);

      await visit("/");
      await click("#create-topic");
      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(2);

      assert
        .dom(".d-editor-input")
        .hasNoValue("event skeleton is not inserted");
      assert
        .dom(".save-or-cancel button.create")
        .hasText(i18n("composer.create_topic"));

      const composerActions = selectKit(".composer-actions");
      await composerActions.expand();
      assert
        .dom(`.composer-actions .select-kit-row[data-value="create_event"]`)
        .doesNotExist("Create event option is not offered");
      assert
        .dom(
          `.composer-actions .select-kit-row[data-value="create_regular_topic"]`
        )
        .doesNotExist();
    });
  }
);
