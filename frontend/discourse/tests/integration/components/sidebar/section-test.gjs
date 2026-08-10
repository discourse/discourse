import { click, find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import Section from "discourse/components/sidebar/section";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  externalDragOver,
  simulateExternalDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";

/** A drag carrying a real URL, the way a link dragged from another tab arrives. */
function urlTransfer() {
  const dataTransfer = new DataTransfer();
  dataTransfer.setData("text/uri-list", "https://example.com/dropped");
  return dataTransfer;
}

/** Selected text, which may or may not turn out to contain a URL. */
function textTransfer() {
  const dataTransfer = new DataTransfer();
  dataTransfer.setData("text/html", "<p>some selected text</p>");
  dataTransfer.setData("text/plain", "some selected text");
  return dataTransfer;
}

function fileTransfer() {
  const dataTransfer = new DataTransfer();
  dataTransfer.items.add(
    new File(["payload"], "a.txt", { type: "text/plain" })
  );
  return dataTransfer;
}

/** Past the midpoint of every link, so a drop lands at the end of the list. */
function belowAllLinks() {
  return {
    clientY: find(".sidebar-section").getBoundingClientRect().bottom - 2,
  };
}

module("Integration | Component | Sidebar | Section", function (hooks) {
  setupRenderingTest(hooks);

  test("default displaySection value for section", async function (assert) {
    const template = <template>
      <Section
        @sectionName="test"
        @headerLinkText="test header"
        @headerLinkTitle="some title"
        @headerActionsIcon="plus"
        @headerActions={{this.headerActions}}
      />
    </template>;

    this.headerActions = [];
    await render(template);

    assert
      .dom(".sidebar-section-wrapper")
      .exists("section is displayed by default if no display arg is provided");
  });

  test("displaySection is dynamic based on argument", async function (assert) {
    const template = <template>
      <Section
        @sectionName="test"
        @headerLinkText="test header"
        @headerLinkTitle="some title"
        @headerActionsIcon="plus"
        @headerActions={{this.headerActions}}
        @displaySection={{this.displaySection}}
      />
    </template>;

    this.displaySection = false;
    this.headerActions = [];
    await render(template);

    assert
      .dom(".sidebar-section-wrapper")
      .doesNotExist("section is not displayed");

    this.set("displaySection", true);
    assert.dom(".sidebar-section-wrapper").exists("section is displayed");
  });

  test("can expand and collapse content when section is collapsible", async function (assert) {
    const template = <template>
      <Section
        @sectionName="test"
        @headerLinkText="test header"
        @headerLinkTitle="some title"
        @headerActionsIcon="plus"
        @headerActions={{this.headerActions}}
        @collapsable={{true}}
      />
    </template>;

    this.headerActions = [];
    await render(template);

    assert.dom(".sidebar-section-content").exists("shows content by default");

    await click(".sidebar-section-header-caret");

    assert
      .dom(".sidebar-section-content")
      .doesNotExist("does not show content after collapsing");
  });

  test("accepts web link drops when enabled", async function (assert) {
    this.onLinkDrop = (source, linkDropIndex) => {
      assert.step("drop");
      assert.strictEqual(
        source.getURLs()[0],
        "https://example.com/dropped",
        "passes the dropped payload to the handler"
      );
      assert.strictEqual(linkDropIndex, 2, "drops after the final link");
    };

    await render(
      <template>
        <Section
          @sectionName="test"
          @headerLinkText="test header"
          @linkDropEnabled={{true}}
          @onLinkDrop={{this.onLinkDrop}}
        >
          <li data-sidebar-custom-link="true">First link</li>
          <li data-sidebar-custom-link="true">Second link</li>
        </Section>
      </template>
    );

    const dataTransfer = urlTransfer();
    await externalDragOver(".sidebar-section", {
      dataTransfer,
      coordinates: belowAllLinks(),
    });

    assert
      .dom(".sidebar-section")
      .hasClass("is-link-drop-active", "shows an active drop state");
    assert
      .dom(".sidebar-section-link-drop-indicator")
      .exists("shows where the link will be appended");

    await triggerEvent(".sidebar-section", "drop", {
      dataTransfer,
      ...belowAllLinks(),
    });

    assert.verifySteps(["drop"], "invokes the drop handler once");
    assert
      .dom(".sidebar-section")
      .doesNotHaveClass("is-link-drop-active", "clears the drop state");
    assert
      .dom(".sidebar-section-link-drop-indicator")
      .doesNotExist("clears the insertion indicator");
  });

  test("does not advertise ambiguous text as a link", async function (assert) {
    await render(
      <template>
        <Section
          @sectionName="test"
          @headerLinkText="test header"
          @linkDropEnabled={{true}}
        />
      </template>
    );

    await externalDragOver(".sidebar-section", {
      dataTransfer: textTransfer(),
    });

    assert
      .dom(".sidebar-section")
      .doesNotHaveClass(
        "is-link-drop-active",
        "does not show a drop affordance for selected text"
      );
  });

  test("stays active while the cursor is over its own contents", async function (assert) {
    await render(
      <template>
        <Section
          @sectionName="test"
          @headerLinkText="test header"
          @linkDropEnabled={{true}}
        />
      </template>
    );

    const dataTransfer = urlTransfer();
    await externalDragOver(".sidebar-section", { dataTransfer });

    // Driven event by event: the header text is deliberately not a drop target,
    // which is what this test is about, so the helper's registration guard
    // would refuse it.
    const overHeader = centerOf(".sidebar-section-header-text");
    await dragEvent(".sidebar-section-header-text", "dragenter", {
      dataTransfer,
      ...overHeader,
    });
    await dragEvent(".sidebar-section-header-text", "dragover", {
      dataTransfer,
      ...overHeader,
    });

    assert
      .dom(".sidebar-section")
      .hasClass(
        "is-link-drop-active",
        "a descendant that is not itself a drop target does not take the section's place"
      );

    await triggerEvent(".sidebar-section", "dragleave", { dataTransfer });

    assert
      .dom(".sidebar-section")
      .doesNotHaveClass(
        "is-link-drop-active",
        "clears the state after leaving the section"
      );
  });

  test("clears the drop state when the drag is abandoned", async function (assert) {
    await render(
      <template>
        <Section
          @sectionName="test"
          @headerLinkText="test header"
          @linkDropEnabled={{true}}
        />
      </template>
    );

    const dataTransfer = urlTransfer();
    await externalDragOver(".sidebar-section", { dataTransfer });
    assert
      .dom(".sidebar-section")
      .hasClass("is-link-drop-active", "shows the active drop state");

    await triggerEvent(document, "dragend", { dataTransfer });

    assert
      .dom(".sidebar-section")
      .doesNotHaveClass(
        "is-link-drop-active",
        "a drag released outside any target still ends the hover state"
      );
  });

  test("does not accept non-link drops", async function (assert) {
    this.onLinkDrop = () => assert.step("drop");

    await render(
      <template>
        <Section
          @sectionName="test"
          @headerLinkText="test header"
          @linkDropEnabled={{true}}
          @onLinkDrop={{this.onLinkDrop}}
        />
      </template>
    );

    await simulateExternalDrag(".sidebar-section", {
      dataTransfer: fileTransfer(),
    });

    assert
      .dom(".sidebar-section")
      .doesNotHaveClass("is-link-drop-active", "does not show a drop state");
    assert.verifySteps([], "does not invoke the drop handler");
  });

  test("does not accept web link drops when disabled", async function (assert) {
    this.onLinkDrop = () => assert.step("drop");

    await render(
      <template>
        <Section
          @sectionName="test"
          @headerLinkText="test header"
          @linkDropEnabled={{false}}
          @onLinkDrop={{this.onLinkDrop}}
        />
      </template>
    );

    await simulateExternalDrag(".sidebar-section", {
      dataTransfer: urlTransfer(),
    });

    assert
      .dom(".sidebar-section")
      .doesNotHaveClass("is-link-drop-active", "does not show a drop state");
    assert.verifySteps([], "does not invoke the drop handler");
  });
});
