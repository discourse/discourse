import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import CompactEventEditor from "discourse/plugins/discourse-events/discourse/components/compact-event-editor";
import { defaultEventState } from "discourse/plugins/discourse-events/discourse/lib/raw-event-helper";

async function renderEditor(initialState, onChange = () => {}) {
  await render(
    <template>
      <CompactEventEditor
        @initialState={{initialState}}
        @onChange={{onChange}}
      />
    </template>
  );
}

function stateWith(overrides) {
  return {
    ...defaultEventState(),
    name: "My event",
    timezone: "UTC",
    startsAt: moment("2026-07-01T10:00:00Z"),
    endsAt: moment("2026-07-01T11:00:00Z"),
    ...overrides,
  };
}

module("Integration | Component | CompactEventEditor", function (hooks) {
  setupRenderingTest(hooks);

  test("exposes an existing url so it can be edited", async function (assert) {
    const initialState = stateWith({ url: "https://meet.example.com/legacy" });
    await renderEditor(initialState);

    assert
      .dom(".composer-event__url-input")
      .hasValue(
        "https://meet.example.com/legacy",
        "a defined url is reachable on the compact screen, not just in advanced"
      );
  });

  test("offers no url row for an event that has none", async function (assert) {
    const initialState = stateWith({ location: "Room 5" });
    await renderEditor(initialState);

    assert
      .dom(".composer-event__url-input")
      .doesNotExist("adding a url is an advanced-screen action");
    assert
      .dom(".composer-event__location-input")
      .hasAttribute(
        "placeholder",
        "Add location or URL",
        "location covers both meanings while it is the only link field"
      );
  });

  test("clearing the url keeps the row so it can be retyped", async function (assert) {
    const initialState = stateWith({ url: "https://meet.example.com/legacy" });
    let lastState = null;
    await renderEditor(initialState, (state) => (lastState = state));

    await fillIn(".composer-event__url-input", "");

    assert.strictEqual(
      lastState.url,
      null,
      "the cleared value is emitted so buildParams drops it"
    );
    assert
      .dom(".composer-event__url-input")
      .exists("the input is not yanked out from under the cursor");
  });

  test("offers the livestream toggle when the url carries the livestream link", async function (assert) {
    this.siteSettings.chat_enabled = true;

    const initialState = stateWith({ url: "https://zoom.us/j/123456789" });
    await renderEditor(initialState);

    assert
      .dom(".composer-event__livestream")
      .exists("a livestream link is recognized in either field");
  });

  test("does not offer livestream for a venue with a companion link", async function (assert) {
    this.siteSettings.chat_enabled = true;

    const initialState = stateWith({
      location: "Room 5",
      url: "https://zoom.us/j/123456789",
    });
    await renderEditor(initialState);

    assert
      .dom(".composer-event__livestream")
      .doesNotExist("the location takes precedence as the livestream source");
  });

  test("keeps the livestream flag when only the companion url changes", async function (assert) {
    this.siteSettings.chat_enabled = true;

    const initialState = stateWith({
      location: "https://zoom.us/j/123456789",
      url: "https://example.com/tickets",
      livestream: true,
    });
    let lastState = null;
    await renderEditor(initialState, (state) => (lastState = state));

    await fillIn(".composer-event__url-input", "https://example.com/register");

    assert
      .dom(".composer-event__livestream")
      .exists("the location still carries the stream");
    assert.true(lastState.livestream, "the flag survives a companion url edit");
  });

  test("ignores a whitespace-only location when the url carries the stream", async function (assert) {
    this.siteSettings.chat_enabled = true;

    const initialState = stateWith({
      url: "https://zoom.us/j/123456789",
      livestream: true,
    });
    let lastState = null;
    await renderEditor(initialState, (state) => (lastState = state));

    await fillIn(".composer-event__location-input", " ");

    assert
      .dom(".composer-event__livestream")
      .exists("a blank location does not shadow the url");
    assert.true(
      lastState.livestream,
      "the flag matches what the save path would keep"
    );
  });

  test("drops the livestream flag when the url stops being the livestream", async function (assert) {
    this.siteSettings.chat_enabled = true;

    const initialState = stateWith({
      url: "https://zoom.us/j/123456789",
      livestream: true,
    });
    let lastState = null;
    await renderEditor(initialState, (state) => (lastState = state));

    await fillIn(".composer-event__url-input", "https://example.com/tickets");

    assert.false(
      lastState.livestream,
      "livestream is reset so it is not submitted for a non-livestream url"
    );
  });

  test("narrows the location placeholder once url has its own row", async function (assert) {
    const initialState = stateWith({
      location: "Room 5",
      url: "https://meet.example.com/legacy",
    });
    await renderEditor(initialState);

    assert
      .dom(".composer-event__location-input")
      .hasAttribute(
        "placeholder",
        "Add location",
        "location stops advertising URLs once url is a separate row"
      );
  });
});
