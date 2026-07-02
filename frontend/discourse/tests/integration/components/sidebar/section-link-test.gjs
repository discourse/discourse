import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import SectionLink from "discourse/components/sidebar/section-link";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Sidebar | SectionLink", function (hooks) {
  setupRenderingTest(hooks);

  function setTouch(owner, value) {
    Object.defineProperty(owner.lookup("service:capabilities"), "touch", {
      configurable: true,
      value,
    });
  }

  test("default class attribute for link", async function (assert) {
    const template = <template>
      <SectionLink @linkName="Test Meta" @route="discovery.latest" />
    </template>;

    await render(template);

    assert
      .dom("a")
      .hasAttribute(
        "class",
        "ember-view sidebar-section-link sidebar-row",
        "has the right class attribute for the link"
      );
  });

  test("custom class attribute for link", async function (assert) {
    const template = <template>
      <SectionLink
        @linkName="Test Meta"
        @route="discovery.latest"
        @linkClass="123 abc"
      />
    </template>;

    await render(template);

    assert
      .dom("a")
      .hasAttribute(
        "class",
        "ember-view sidebar-section-link sidebar-row 123 abc",
        "has the right class attribute for the link"
      );
  });

  test("target attribute for link", async function (assert) {
    const template = <template>
      <SectionLink @linkName="test" @href="https://discourse.org" />
    </template>;
    await render(template);

    assert.dom("a").hasAttribute("target", "_self");
  });

  test("target attribute for link when user set external links in new tab", async function (assert) {
    this.currentUser.user_option.external_links_in_new_tab = true;
    const template = <template>
      <SectionLink @linkName="test" @href="https://discourse.org" />
    </template>;
    await render(template);

    assert.dom("a").hasAttribute("target", "_blank");
  });

  test("hover action is rendered on non-touch devices", async function (assert) {
    setTouch(this.owner, false);

    const template = <template>
      <SectionLink
        @linkName="test"
        @route="discovery.latest"
        @hoverType="icon"
        @hoverValue="ellipsis-vertical"
      />
    </template>;

    await render(template);

    assert.dom(".sidebar-section-hover-button").exists();

    await triggerEvent(".sidebar-section-link-wrapper", "mouseenter");

    assert.dom(".sidebar-section-link-wrapper").hasClass("--hovering");
  });

  test("hover action is not rendered on touch devices", async function (assert) {
    setTouch(this.owner, true);

    const template = <template>
      <SectionLink
        @linkName="test"
        @route="discovery.latest"
        @hoverType="icon"
        @hoverValue="ellipsis-vertical"
      />
    </template>;

    await render(template);

    assert.dom(".sidebar-section-hover-button").doesNotExist();

    await triggerEvent(".sidebar-section-link-wrapper", "mouseenter");

    assert.dom(".sidebar-section-link-wrapper").doesNotHaveClass("--hovering");
  });
});
