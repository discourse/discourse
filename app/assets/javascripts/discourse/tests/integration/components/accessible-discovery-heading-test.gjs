import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";

module("Component | discovery/accessible-discovery-heading", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders the correct label for categories filter", async function (assert) {
    this.set("filter", "categories");

    await render(
      hbs`<Discovery::AccessibleDiscoveryHeading @filter={{this.filter}} />`
    );

    assert
      .dom("#topic-list-heading")
      .hasText("All categories", "The label is correct for categories filter");
  });

  test("it renders the correct label for a single tag", async function (assert) {
    this.setProperties({
      filter: "top",
      tag: { id: "javascript" },
    });

    await render(
      hbs`<Discovery::AccessibleDiscoveryHeading @filter={{this.filter}} @tag={{this.tag}} />`
    );

    assert
      .dom("#topic-list-heading")
      .hasText(
        "Top topics tagged javascript",
        "The label is correct for a single tag"
      );
  });

  test("it renders the correct label for a category and tag", async function (assert) {
    this.setProperties({
      filter: "latest",
      category: { name: "Development" },
      tag: { id: "javascript" },
    });

    await render(
      hbs`<Discovery::AccessibleDiscoveryHeading @filter={{this.filter}} @category={{this.category}} @tag={{this.tag}} />`
    );

    assert
      .dom("#topic-list-heading")
      .hasText(
        "Latest topics in Development tagged javascript",
        "The label is correct for a category and tag"
      );
  });

  test("it renders nothing for no filter", async function (assert) {
    await render(hbs`<Discovery::AccessibleDiscoveryHeading />`);

    assert.dom("#topic-list-heading").doesNotExist("The label is not shown");
  });
});
