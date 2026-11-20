import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";

module("Integration | ui-kit | DNavigationItem", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.setupRouter();
    const router = getOwner(this).lookup("service:router");
    this.currentRouteName = sinon.stub(router, "currentRouteName");
    this.currentRoute = sinon.stub(router, "currentRoute");
    this.currentRoute.value({ parent: { name: "application" } });
  });

  test("renders a link to @route with its block", async function (assert) {
    this.currentRouteName.value("discovery.top");

    await render(
      <template>
        <DNavigationItem
          class="extra"
          @class="nav-latest"
          @route="discovery.latest"
          @title="Latest topics"
        >Latest</DNavigationItem>
      </template>
    );

    assert
      .dom("li.nav-latest.extra")
      .hasAttribute("title", "Latest topics", "@title reaches the item")
      .doesNotHaveAttribute("aria-current", "another route is not current");
    assert
      .dom("li.nav-latest a")
      .hasText("Latest", "the block is the link text")
      .hasAttribute("href", "/latest", "the link points at @route");
  });

  test("links to @route with @models or @model", async function (assert) {
    this.currentRouteName.value("discovery.latest");

    await render(
      <template>
        <DNavigationItem
          class="with-models"
          @models={{Array "general/4"}}
          @route="discovery.category"
        >Models</DNavigationItem>
        <DNavigationItem
          class="with-model"
          @model="general/4"
          @route="discovery.category"
        >Model</DNavigationItem>
      </template>
    );

    assert
      .dom(".with-models a")
      .hasAttribute("href", "/c/general/4", "the link passes @models");
    assert
      .dom(".with-model a")
      .hasAttribute("href", "/c/general/4", "the link passes @model");
  });

  test("marks the current route as the current page", async function (assert) {
    this.currentRouteName.value("discovery.latest");

    await render(
      <template>
        <DNavigationItem @route="discovery.latest">Latest</DNavigationItem>
      </template>
    );

    assert.dom("li").hasAttribute("aria-current", "page");
  });

  test("marks the current route as the location in a sub-navigation", async function (assert) {
    this.currentRouteName.value("discovery.latest");

    await render(
      <template>
        <DNavigationItem
          @ariaCurrentContext="subNav"
          @route="discovery.latest"
        >Latest</DNavigationItem>
      </template>
    );

    assert.dom("li").hasAttribute("aria-current", "location");
  });

  test("marks the parent of the current route as the page in a parent navigation", async function (assert) {
    this.currentRouteName.value("discovery.latest");
    this.currentRoute.value({ parent: { name: "discovery" } });

    await render(
      <template>
        <DNavigationItem
          class="parent"
          @ariaCurrentContext="parentNav"
          @route="discovery"
        >Discovery</DNavigationItem>
        <DNavigationItem
          class="other"
          @ariaCurrentContext="parentNav"
          @route="review"
        >Review</DNavigationItem>
      </template>
    );

    assert.dom("li.parent").hasAttribute("aria-current", "page");
    assert
      .dom("li.other")
      .doesNotHaveAttribute(
        "aria-current",
        "an unrelated route is not current"
      );
  });
});
