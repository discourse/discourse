import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import Section from "discourse/components/sidebar/section";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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
    this.dataTransfer = {
      types: ["text/uri-list"],
      dropEffect: null,
    };
    this.onLinkDrop = (dataTransfer, linkDropIndex) => {
      assert.step("drop");
      assert.strictEqual(
        dataTransfer,
        this.dataTransfer,
        "passes the dropped data to the handler"
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

    await triggerEvent(".sidebar-section", "dragover", {
      dataTransfer: this.dataTransfer,
    });

    assert
      .dom(".sidebar-section")
      .hasClass("is-link-drop-active", "shows an active drop state");
    assert
      .dom(".sidebar-section-link-drop-indicator")
      .exists("shows where the link will be appended");
    assert.strictEqual(
      this.dataTransfer.dropEffect,
      "copy",
      "indicates that the link will be copied"
    );

    await triggerEvent(".sidebar-section", "drop", {
      dataTransfer: this.dataTransfer,
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
    const dataTransfer = {
      types: ["text/html", "text/plain"],
      dropEffect: null,
    };

    await render(
      <template>
        <Section
          @sectionName="test"
          @headerLinkText="test header"
          @linkDropEnabled={{true}}
        />
      </template>
    );

    await triggerEvent(".sidebar-section", "dragover", { dataTransfer });

    assert
      .dom(".sidebar-section")
      .doesNotHaveClass(
        "is-link-drop-active",
        "does not show a drop affordance for selected text"
      );
  });

  test("tracks nested drag enter and leave events", async function (assert) {
    const dataTransfer = {
      types: ["text/uri-list"],
      dropEffect: null,
    };

    await render(
      <template>
        <Section
          @sectionName="test"
          @headerLinkText="test header"
          @linkDropEnabled={{true}}
        />
      </template>
    );

    await triggerEvent(".sidebar-section", "dragenter", { dataTransfer });
    await triggerEvent(".sidebar-section-header-text", "dragenter", {
      dataTransfer,
    });
    await triggerEvent(".sidebar-section-header-text", "dragover", {
      dataTransfer,
    });
    await triggerEvent(".sidebar-section-header-text", "dragleave", {
      dataTransfer,
    });

    assert
      .dom(".sidebar-section")
      .hasClass("is-link-drop-active", "keeps the nested drag active");

    await triggerEvent(".sidebar-section", "dragleave", { dataTransfer });

    assert
      .dom(".sidebar-section")
      .doesNotHaveClass(
        "is-link-drop-active",
        "clears the state after leaving the section"
      );
  });

  test("clears the drop state when dragging ends", async function (assert) {
    const dataTransfer = {
      types: ["text/uri-list"],
      dropEffect: null,
    };

    await render(
      <template>
        <Section
          @sectionName="test"
          @headerLinkText="test header"
          @linkDropEnabled={{true}}
        />
      </template>
    );

    await triggerEvent(".sidebar-section", "dragenter", { dataTransfer });
    await triggerEvent(".sidebar-section", "dragover", { dataTransfer });
    assert
      .dom(".sidebar-section")
      .hasClass("is-link-drop-active", "shows the active drop state");

    await triggerEvent(document, "dragend", { dataTransfer });
    assert
      .dom(".sidebar-section")
      .doesNotHaveClass("is-link-drop-active", "clears the drop state");
  });

  test("does not accept non-link drops", async function (assert) {
    this.onLinkDrop = () => assert.step("drop");
    const dataTransfer = {
      types: ["Files"],
      dropEffect: null,
    };

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

    await triggerEvent(".sidebar-section", "dragover", { dataTransfer });
    await triggerEvent(".sidebar-section", "drop", { dataTransfer });

    assert
      .dom(".sidebar-section")
      .doesNotHaveClass("is-link-drop-active", "does not show a drop state");
    assert.verifySteps([], "does not invoke the drop handler");
  });

  test("does not accept web link drops when disabled", async function (assert) {
    this.onLinkDrop = () => assert.step("drop");
    const dataTransfer = {
      types: ["text/uri-list"],
      dropEffect: null,
    };

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

    await triggerEvent(".sidebar-section", "dragover", { dataTransfer });
    await triggerEvent(".sidebar-section", "drop", { dataTransfer });

    assert
      .dom(".sidebar-section")
      .doesNotHaveClass("is-link-drop-active", "does not show a drop state");
    assert.verifySteps([], "does not invoke the drop handler");
  });
});
