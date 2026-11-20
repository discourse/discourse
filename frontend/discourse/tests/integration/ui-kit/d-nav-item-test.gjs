import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DNavItem from "discourse/ui-kit/d-nav-item";
import I18n from "discourse-i18n";

module("Integration | ui-kit | DNavItem", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    I18n.translations[I18n.locale].js.test_nav_item = { label: "Overview" };
    this.owner.setupRouter();
    this.router = getOwner(this).lookup("service:router");
    this.currentRoute = sinon.stub(this.router, "currentRoute");
    this.currentRoute.value({ name: "discovery.top", params: {} });
  });

  test("links to @path with the translated @label", async function (assert) {
    await render(
      <template>
        <DNavItem
          class="extra"
          @class="overview"
          @label="test_nav_item.label"
          @path="/about"
        />
      </template>
    );

    assert
      .dom("li.overview.extra a")
      .hasText("Overview", "@label is translated")
      .hasAttribute("href", "/about", "the link points at @path")
      .hasAttribute("data-auto-route", "true");
  });

  test("shows @i18nLabel with @icon", async function (assert) {
    await render(
      <template>
        <DNavItem
          @i18nLabel="Already translated"
          @icon="gear"
          @label="test_nav_item.label"
          @path="/about"
        />
      </template>
    );

    assert.dom("li a").hasText("Already translated", "@i18nLabel wins");
    assert.dom("li a .d-icon-gear").exists("the icon precedes the label");
  });

  test("links to @route and marks it active when it is the current route", async function (assert) {
    sinon.stub(this.router, "isActive").returns(true);

    await render(
      <template>
        <DNavItem @label="test_nav_item.label" @route="discovery.latest" />
      </template>
    );

    assert.dom("li").hasClass("active", "the current route is active");
    assert.dom("li a").hasAttribute("href", "/latest");
  });

  test("@currentWhen decides whether the item is active", async function (assert) {
    await render(
      <template>
        <DNavItem
          class="as-true"
          @currentWhen={{true}}
          @label="test_nav_item.label"
          @route="discovery.latest"
        />
        <DNavItem
          class="as-list"
          @currentWhen="discovery.new discovery.top"
          @label="test_nav_item.label"
          @route="discovery.latest"
        />
        <DNavItem
          class="as-other-list"
          @currentWhen="discovery.new discovery.unread"
          @label="test_nav_item.label"
          @route="discovery.latest"
        />
      </template>
    );

    assert.dom("li.as-true").hasClass("active", "true is active");
    assert
      .dom("li.as-list")
      .hasClass("active", "a list naming the current route is active");
    assert
      .dom("li.as-other-list")
      .doesNotHaveClass("active", "a list without it is not");
  });

  test("@routeParam compares with the current filter", async function (assert) {
    this.currentRoute.value({
      name: "discovery.filter",
      params: { filter: "hot" },
    });

    await render(
      <template>
        <DNavItem
          class="hot"
          @label="test_nav_item.label"
          @route="discovery.category"
          @routeParam="hot"
        />
        <DNavItem
          class="new"
          @label="test_nav_item.label"
          @route="discovery.category"
          @routeParam="new"
        />
      </template>
    );

    assert.dom("li.hot").hasClass("active", "the current filter is active");
    assert.dom("li.new").doesNotHaveClass("active", "another one is not");
    assert
      .dom("li.hot a")
      .hasAttribute("href", "/c/hot", "the link passes @routeParam");
  });

  test("links with a full page load when the session needs a refresh", async function (assert) {
    this.session.set("requiresRefresh", true);

    await render(
      <template>
        <DNavItem @label="test_nav_item.label" @route="discovery.latest" />
      </template>
    );

    assert
      .dom("li a")
      .hasAttribute("href", "/latest")
      .doesNotHaveClass("ember-view", "it is a plain link, not a route link");
    assert.dom("li a").hasText("Overview");
  });
});
