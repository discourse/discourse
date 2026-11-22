import { trustHTML } from "@ember/template";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DResponsiveTable from "discourse/ui-kit/d-responsive-table";

module("Integration | ui-kit | DResponsiveTable", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the header and body blocks in a table", async function (assert) {
    await render(
      <template>
        <DResponsiveTable>
          <:header><span class="test-heading">Name</span></:header>
          <:body><span class="test-cell">Alice</span></:body>
        </DResponsiveTable>
      </template>
    );

    assert
      .dom(
        ".directory-table[role='table'] .directory-table__header .test-heading"
      )
      .exists("the header block is rendered in the header row");
    assert
      .dom(".directory-table[role='table'] .directory-table__body .test-cell")
      .exists("the body block is rendered in the body");
  });

  test("applies @className, @ariaLabel and @style to the table", async function (assert) {
    const style = trustHTML("grid-template-columns: 1fr 2fr");

    await render(
      <template>
        <DResponsiveTable
          @ariaLabel="Members"
          @className="members-table"
          @style={{style}}
        />
      </template>
    );

    assert
      .dom(".directory-table")
      .hasClass("members-table", "@className is added")
      .hasAria("label", "Members", "@ariaLabel names the table")
      .hasAttribute(
        "style",
        "grid-template-columns: 1fr 2fr",
        "@style is applied to the table"
      );
  });

  test("attributes reach the scroll container", async function (assert) {
    await render(<template><DResponsiveTable data-test-table /></template>);

    assert
      .dom(".directory-table-container")
      .hasAttribute("data-test-table", "", "attributes are applied")
      .hasClass(
        "horizontal-scroll-sync__container",
        "the container is the scroll-sync wrapper"
      );
  });
});
