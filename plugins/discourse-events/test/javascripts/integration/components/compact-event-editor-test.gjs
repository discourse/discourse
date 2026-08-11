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
