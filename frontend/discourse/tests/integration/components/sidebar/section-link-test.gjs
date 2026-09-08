import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import SectionLink from "discourse/components/sidebar/section-link";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Sidebar | SectionLink", function (hooks) {
  setupRenderingTest(hooks);

  function setTouch(owner, value) {
    sinon.stub(owner.lookup("service:capabilities"), "touch").get(() => value);
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
        @linkClass="123 abc"
        @linkName="Test Meta"
        @route="discovery.latest"
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
      <SectionLink @href="https://discourse.org" @linkName="test" />
    </template>;
    await render(template);

    assert.dom("a").hasAttribute("target", "_self");
  });

  test("target attribute for link when user set external links in new tab", async function (assert) {
    this.currentUser.user_option.external_links_in_new_tab = true;
    const template = <template>
      <SectionLink @href="https://discourse.org" @linkName="test" />
    </template>;
    await render(template);

    assert.dom("a").hasAttribute("target", "_blank");
  });

  test("hover action is rendered on non-touch devices", async function (assert) {
    setTouch(this.owner, false);

    const template = <template>
      <SectionLink
        @hoverType="icon"
        @hoverValue="ellipsis-vertical"
        @linkName="test"
        @route="discovery.latest"
      />
    </template>;

    await render(template);

    assert.dom(".sidebar-section-hover-button").exists();

    await triggerEvent(".sidebar-section-link-wrapper", "mouseenter");

    assert.dom(".sidebar-section-link-wrapper").hasClass("--hovering");
  });

  test("hover action is not rendered on touch devices with a narrow viewport", async function (assert) {
    setTouch(this.owner, true);
    sinon
      .stub(this.owner.lookup("service:capabilities"), "viewport")
      .value({ sm: false });

    const template = <template>
      <SectionLink
        @hoverType="icon"
        @hoverValue="ellipsis-vertical"
        @linkName="test"
        @route="discovery.latest"
      />
    </template>;

    await render(template);

    assert
      .dom(".sidebar-section-hover-button")
      .doesNotExist("does not clutter the narrow layout with a button");
  });

  test("hover action is rendered on touch devices with a wide viewport, without the hovering state", async function (assert) {
    setTouch(this.owner, true);

    const template = <template>
      <SectionLink
        @hoverType="icon"
        @hoverValue="ellipsis-vertical"
        @linkName="test"
        @route="discovery.latest"
      />
    </template>;

    await render(template);

    assert
      .dom(".sidebar-section-hover-button")
      .exists("the button is rendered without needing hover");

    await triggerEvent(".sidebar-section-link-wrapper", "mouseenter");

    assert
      .dom(".sidebar-section-link-wrapper")
      .doesNotHaveClass("--hovering", "emulated hover does not set the state");
  });

  test("scrollIntoView measures against the scrolling ancestor, not the window", async function (assert) {
    // A scroller shorter than the window, with the link pushed below its
    // visible area but still well inside the viewport.
    await render(
      <template>
        <div
          class="test-scroller"
          style="height: 300px; overflow-y: auto; position: relative"
        >
          <div style="height: 600px"></div>
          <SectionLink
            @linkName="target"
            @route="discovery.latest"
            @scrollIntoView={{true}}
          />
          {{! trailing content, so centring the row is actually reachable }}
          <div style="height: 600px"></div>
        </div>
      </template>
    );

    const scroller = document.querySelector(".test-scroller");
    const link = document.querySelector("[data-list-item-name='target']");

    assert.true(
      link.getBoundingClientRect().top < window.innerHeight,
      "precondition: the link is inside the viewport"
    );
    assert.true(
      scroller.scrollTop > 0,
      "the scroller was scrolled to bring the link into its own view"
    );

    const linkRect = link.getBoundingClientRect();
    const scrollerRect = scroller.getBoundingClientRect();

    assert.true(
      linkRect.top >= scrollerRect.top - 1,
      "the link's top is inside the scroller"
    );
    assert.true(
      linkRect.bottom <= scrollerRect.bottom + 1,
      "the link's bottom is inside the scroller"
    );

    // centring would have scrolled roughly half a container further; the row is
    // revealed near the edge instead, offset by its scroll-margin
    const centeredScrollTop =
      link.offsetTop - (scroller.clientHeight - link.offsetHeight) / 2;

    assert.true(
      scroller.scrollTop < centeredScrollTop,
      "the scroller moved less than centring the row would have"
    );
  });

  test("scrollIntoView accounts for an outer scroller too", async function (assert) {
    // Visible inside its nearest scroller, but clipped by the one outside it.
    await render(
      <template>
        <div
          class="test-outer"
          style="height: 100px; overflow-y: auto; position: relative"
        >
          <div style="height: 400px"></div>
          <div
            class="test-inner"
            style="height: 60px; overflow-y: auto; position: relative"
          >
            <SectionLink
              @linkName="target"
              @route="discovery.latest"
              @scrollIntoView={{true}}
            />
            {{! makes the inner scroller genuinely overflow }}
            <div style="height: 300px"></div>
          </div>
          <div style="height: 400px"></div>
        </div>
      </template>
    );

    const outer = document.querySelector(".test-outer");
    const link = document.querySelector("[data-list-item-name='target']");
    const linkRect = link.getBoundingClientRect();
    const outerRect = outer.getBoundingClientRect();

    assert.true(outer.scrollTop > 0, "the outer scroller moved");
    assert.true(
      linkRect.top >= outerRect.top - 1,
      "the link's top is inside the outer scroller"
    );
    assert.true(
      linkRect.bottom <= outerRect.bottom + 1,
      "the link's bottom is inside the outer scroller"
    );
  });

  test("scrollIntoView leaves an already visible link alone", async function (assert) {
    await render(
      <template>
        <div
          class="test-scroller"
          style="height: 300px; overflow-y: auto; position: relative"
        >
          <SectionLink
            @linkName="target"
            @route="discovery.latest"
            @scrollIntoView={{true}}
          />
          <div style="height: 400px"></div>
        </div>
      </template>
    );

    assert.strictEqual(
      document.querySelector(".test-scroller").scrollTop,
      0,
      "no scrolling happens when the link is already fully in view"
    );
  });
});
