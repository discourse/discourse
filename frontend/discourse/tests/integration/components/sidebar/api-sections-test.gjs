import { click, fillIn, find, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Sidebar from "discourse/components/sidebar";
import ApiSections from "discourse/components/sidebar/api-sections";
import BaseCustomSidebarPanel from "discourse/lib/sidebar/base-custom-sidebar-panel";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function link(name, text, currentWhen = false) {
  return new (class extends BaseCustomSidebarSectionLink {
    name = name;
    text = text;
    title = text;
    href = `#${name}`;
    currentWhen = currentWhen;
  })();
}

function linkItem(name, text) {
  return { type: "link", link: link(name, text) };
}

function section({ name, text, links, items, collapsedByDefault = false }) {
  return class extends BaseCustomSidebarSection {
    name = name;
    text = text;
    links = links;
    items = items;
    collapsedByDefault = collapsedByDefault;
  };
}

function nestedSections({ collapsedByDefault = false, active = false } = {}) {
  const SidebarGroup = section({
    name: "sidebar",
    text: "Sidebar",
    links: [link("sidebar-items", "Sidebar items", active)],
    collapsedByDefault,
  });
  const Docs = section({
    name: "docs",
    text: "Docs",
    items: [
      linkItem("create", "Create a doc"),
      { type: "section", section: SidebarGroup },
    ],
    collapsedByDefault,
  });
  const Guides = section({
    name: "guides",
    text: "Guides",
    items: [
      linkItem("pages", "Pages"),
      { type: "section", section: Docs },
      linkItem("reference", "Reference"),
    ],
    collapsedByDefault,
  });

  return [Guides];
}

function configurePanel(owner, sections, { filterableMinLinks = 0 } = {}) {
  const panel = new (class extends BaseCustomSidebarPanel {
    key = "test";
    displayHeader = true;
    backLink = { href: "/" };
    filterable = true;
    filterableMinLinks = filterableMinLinks;
  })();
  panel.sections = sections;

  const sidebarState = owner.lookup("service:sidebar-state");
  sidebarState.panels = [panel];
  sidebarState.setPanel(panel.key);
  sidebarState.setSeparatedMode();
}

function header(sectionName) {
  return `[data-section-name="${sectionName}"] > .sidebar-section-header-wrapper > button`;
}

module("Integration | Component | Sidebar | ApiSections", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  test("renders a section that supplies only links", async function (assert) {
    configurePanel(this.owner, [
      section({
        name: "resources",
        text: "Resources",
        links: [link("pages", "Pages"), link("reference", "Reference")],
      }),
    ]);

    await render(<template><ApiSections @collapsable={{true}} /></template>);

    assert
      .dom(header("resources"))
      .hasText("Resources", "renders the legacy section header");
    assert.deepEqual(
      findAll(".sidebar-section-content > li > a").map((row) =>
        row.textContent.trim()
      ),
      ["Pages", "Reference"],
      "renders legacy links in their supplied order"
    );
  });

  test("renders links and subsections in order across three levels", async function (assert) {
    configurePanel(this.owner, nestedSections());

    await render(<template><ApiSections @collapsable={{true}} /></template>);

    assert
      .dom(
        '[data-section-name="guides"] > ul > li > [data-section-name="guides/docs"]'
      )
      .exists("the child section is a list item in its parent");
    assert
      .dom(
        '[data-section-name="guides/docs"] > ul > li > [data-section-name="guides/docs/sidebar"]'
      )
      .exists("the third level nests in the child section's list");
    assert.deepEqual(
      findAll(".sidebar-section-link").map((row) => row.textContent.trim()),
      ["Pages", "Create a doc", "Sidebar items", "Reference"],
      "links can appear on either side of a child section"
    );
  });

  test("items take precedence over links", async function (assert) {
    configurePanel(this.owner, [
      section({
        name: "resources",
        text: "Resources",
        links: [link("legacy", "Legacy")],
        items: [linkItem("current", "Current")],
      }),
    ]);

    await render(<template><ApiSections @collapsable={{true}} /></template>);

    assert.dom('[data-link-name="current"]').exists("renders the items link");
    assert
      .dom('[data-link-name="legacy"]')
      .doesNotExist("does not also render the legacy link");
  });

  test("filtering reveals matching descendants and restores collapse state when cleared", async function (assert) {
    configurePanel(this.owner, nestedSections({ collapsedByDefault: true }), {
      filterableMinLinks: 4,
    });

    await render(<template><ApiSections @collapsable={{true}} /></template>);

    assert
      .dom(".sidebar-filter__input")
      .exists("links in collapsed descendants count toward the threshold");
    await fillIn(".sidebar-filter__input", "sidebar items");

    assert
      .dom('[data-link-name="sidebar-items"]')
      .exists("a matching link is visible through all of its ancestors");
    assert
      .dom(".sidebar-section-link")
      .exists({ count: 1 }, "unmatched links are hidden");

    await fillIn(".sidebar-filter__input", "docs");

    assert
      .dom('[data-link-name="sidebar-items"]')
      .exists("a matching section title reveals links in its descendants");
    assert
      .dom('[data-link-name="create"]')
      .exists("the matching section's own link is also visible");
    assert
      .dom('[data-link-name="pages"]')
      .doesNotExist("links outside the matching section stay hidden");

    await fillIn(".sidebar-filter__input", "");

    assert
      .dom(header("guides"))
      .hasAttribute("aria-expanded", "false", "the root stays collapsed");
  });

  test("an active descendant expands every ancestor", async function (assert) {
    configurePanel(
      this.owner,
      nestedSections({ collapsedByDefault: true, active: true })
    );

    await render(
      <template>
        <ApiSections @collapsable={{true}} @expandActiveSection={{true}} />
      </template>
    );

    for (const name of ["guides", "guides/docs", "guides/docs/sidebar"]) {
      assert
        .dom(header(name))
        .hasAttribute(
          "aria-expanded",
          "true",
          `${name} opens on the active path`
        );
    }
    assert
      .dom('[data-link-name="sidebar-items"]')
      .hasClass("active", "the deep link is visible and active");
  });

  test("expand and collapse all reaches sections inside collapsed parents", async function (assert) {
    configurePanel(this.owner, nestedSections({ collapsedByDefault: true }));

    await render(<template><ApiSections @collapsable={{true}} /></template>);

    await click(".sidebar-toggle-all-sections");
    assert
      .dom('[data-link-name="sidebar-items"]')
      .exists("expand all opens the third level even when initially unmounted");

    await click(".sidebar-toggle-all-sections");
    await click(header("guides"));
    assert
      .dom(header("guides/docs"))
      .hasAttribute("aria-expanded", "false", "collapse all closes the child");

    await click(header("guides/docs"));
    assert
      .dom(header("guides/docs/sidebar"))
      .hasAttribute(
        "aria-expanded",
        "false",
        "collapse all closes the third level"
      );
  });

  test("sections with the same name under different parents collapse independently", async function (assert) {
    const Child = section({
      name: "details",
      text: "Details",
      links: [link("more", "More details")],
    });
    configurePanel(
      this.owner,
      ["first", "second"].map((name) =>
        section({
          name,
          text: name,
          items: [{ type: "section", section: Child }],
        })
      )
    );

    await render(<template><ApiSections @collapsable={{true}} /></template>);

    const firstHeader = find(header("first/details"));
    const secondHeader = find(header("second/details"));
    assert.notStrictEqual(
      firstHeader.getAttribute("aria-controls"),
      secondHeader.getAttribute("aria-controls"),
      "the disclosures control different lists"
    );

    await click(firstHeader);
    assert
      .dom(firstHeader)
      .hasAttribute("aria-expanded", "false", "the clicked section collapses");
    assert
      .dom(secondHeader)
      .hasAttribute("aria-expanded", "true", "the other section stays open");
  });

  test("a nested disclosure leaves the mobile sidebar open", async function (assert) {
    configurePanel(this.owner, nestedSections());
    sinon.stub(this.site, "mobileView").value(true);
    const toggleSidebar = () => assert.step("close");

    await render(
      <template>
        <div class="sidebar-wrapper"><Sidebar
            @toggleSidebar={{toggleSidebar}}
          /></div>
      </template>
    );

    await click(header("guides/docs"));
    assert
      .dom(header("guides/docs"))
      .hasAttribute("aria-expanded", "false", "the nested section closes");
    assert.verifySteps([], "the sidebar itself stays open");

    const pagesLink = find('[data-link-name="pages"]');
    pagesLink.addEventListener("click", (event) => event.preventDefault(), {
      once: true,
    });
    await click(pagesLink);
    assert.verifySteps(["close"], "clicking a link still closes the sidebar");
  });
});
