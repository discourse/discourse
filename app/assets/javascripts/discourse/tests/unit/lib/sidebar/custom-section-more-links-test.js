import { module, test } from "qunit";
import {
  addCustomSectionMoreLink,
  getCustomSectionMoreLinks,
  resetCustomSectionMoreLinks,
} from "discourse/lib/sidebar/custom-section-more-links";

module("Unit | Utility | sidebar/custom-section-more-links", function (hooks) {
  hooks.afterEach(function () {
    resetCustomSectionMoreLinks();
  });

  test("addCustomSectionMoreLink with object argument", function (assert) {
    addCustomSectionMoreLink("test-section", {
      name: "test-link",
      text: "Test Link",
      route: "discovery.latest",
      title: "Test Title",
      icon: "star",
    });

    const links = getCustomSectionMoreLinks("test-section");
    assert.strictEqual(links.length, 1, "adds one link to the section");

    const LinkClass = links[0];
    const linkInstance = new LinkClass();

    assert.strictEqual(linkInstance.name, "test-link", "sets correct name");
    assert.strictEqual(linkInstance.text, "Test Link", "sets correct text");
    assert.strictEqual(
      linkInstance.route,
      "discovery.latest",
      "sets correct route"
    );
    assert.strictEqual(linkInstance.title, "Test Title", "sets correct title");
    assert.strictEqual(
      linkInstance.prefixValue,
      "star",
      "sets correct icon as prefix"
    );
    assert.strictEqual(
      linkInstance.prefixType,
      "icon",
      "sets prefix type to icon when icon provided"
    );
  });

  test("addCustomSectionMoreLink with href instead of route", function (assert) {
    addCustomSectionMoreLink("test-section", {
      name: "external-link",
      text: "External Link",
      href: "https://example.com",
      title: "External",
    });

    const links = getCustomSectionMoreLinks("test-section");
    const LinkClass = links[0];
    const linkInstance = new LinkClass();

    assert.strictEqual(
      linkInstance.href,
      "https://example.com",
      "sets correct href"
    );
    assert.strictEqual(
      linkInstance.route,
      undefined,
      "does not set route when href provided"
    );
  });

  test("addCustomSectionMoreLink with callback function", function (assert) {
    addCustomSectionMoreLink("test-section", (BaseSectionLink) => {
      return class extends BaseSectionLink {
        name = "callback-link";
        text = "Callback Link";
        route = "discovery.categories";

        get title() {
          return "Dynamic Title";
        }

        get prefixType() {
          return "icon";
        }

        get prefixValue() {
          return "list";
        }
      };
    });

    const links = getCustomSectionMoreLinks("test-section");
    assert.strictEqual(links.length, 1, "adds callback-based link");

    const LinkClass = links[0];
    const linkInstance = new LinkClass();

    assert.strictEqual(
      linkInstance.name,
      "callback-link",
      "callback link has correct name"
    );
    assert.strictEqual(
      linkInstance.text,
      "Callback Link",
      "callback link has correct text"
    );
    assert.strictEqual(
      linkInstance.title,
      "Dynamic Title",
      "callback link supports dynamic properties"
    );
  });

  test("multiple links for same section", function (assert) {
    addCustomSectionMoreLink("test-section", {
      name: "link-1",
      text: "Link 1",
      route: "discovery.latest",
    });

    addCustomSectionMoreLink("test-section", {
      name: "link-2",
      text: "Link 2",
      route: "discovery.categories",
    });

    const links = getCustomSectionMoreLinks("test-section");
    assert.strictEqual(links.length, 2, "adds multiple links to same section");

    const link1 = new links[0]();
    const link2 = new links[1]();

    assert.strictEqual(link1.name, "link-1", "first link has correct name");
    assert.strictEqual(link2.name, "link-2", "second link has correct name");
  });

  test("links for different sections", function (assert) {
    addCustomSectionMoreLink("section-1", {
      name: "link-1",
      text: "Link 1",
      route: "discovery.latest",
    });

    addCustomSectionMoreLink("section-2", {
      name: "link-2",
      text: "Link 2",
      route: "discovery.categories",
    });

    const section1Links = getCustomSectionMoreLinks("section-1");
    const section2Links = getCustomSectionMoreLinks("section-2");

    assert.strictEqual(section1Links.length, 1, "section-1 has one link");
    assert.strictEqual(section2Links.length, 1, "section-2 has one link");

    const link1 = new section1Links[0]();
    const link2 = new section2Links[0]();

    assert.strictEqual(link1.name, "link-1", "section-1 has correct link");
    assert.strictEqual(link2.name, "link-2", "section-2 has correct link");
  });

  test("getCustomSectionMoreLinks for non-existent section", function (assert) {
    const links = getCustomSectionMoreLinks("non-existent-section");
    assert.strictEqual(
      links.length,
      0,
      "returns empty array for non-existent section"
    );
  });

  test("resetCustomSectionMoreLinks", function (assert) {
    addCustomSectionMoreLink("test-section", {
      name: "test-link",
      text: "Test Link",
      route: "discovery.latest",
    });

    assert.strictEqual(
      getCustomSectionMoreLinks("test-section").length,
      1,
      "link exists before reset"
    );

    resetCustomSectionMoreLinks();

    assert.strictEqual(
      getCustomSectionMoreLinks("test-section").length,
      0,
      "links cleared after reset"
    );
  });

  test("title defaults to text when not provided", function (assert) {
    addCustomSectionMoreLink("test-section", {
      name: "test-link",
      text: "Test Link",
      route: "discovery.latest",
    });

    const links = getCustomSectionMoreLinks("test-section");
    const LinkClass = links[0];
    const linkInstance = new LinkClass();

    assert.strictEqual(
      linkInstance.title,
      "Test Link",
      "title defaults to text value"
    );
  });

  test("prefix type not set when no icon provided", function (assert) {
    addCustomSectionMoreLink("test-section", {
      name: "test-link",
      text: "Test Link",
      route: "discovery.latest",
    });

    const links = getCustomSectionMoreLinks("test-section");
    const LinkClass = links[0];
    const linkInstance = new LinkClass();

    assert.strictEqual(
      linkInstance.prefixType,
      undefined,
      "prefix type not set when no icon"
    );
    assert.strictEqual(
      linkInstance.prefixValue,
      undefined,
      "prefix value not set when no icon"
    );
  });
});
