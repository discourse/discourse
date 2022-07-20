import { test } from "qunit";

import { click, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { withPluginApi } from "discourse/lib/plugin-api";
import { resetSidebarSection } from "discourse/lib/sidebar/custom-sections";
import { bind } from "discourse-common/utils/decorators";
import { undockSidebar } from "discourse/tests/helpers/sidebar-helpers";

acceptance("Sidebar - Plugin API", function (needs) {
  needs.user({ experimental_sidebar_enabled: true });

  needs.hooks.afterEach(() => {
    resetSidebarSection();
    linkDestroy = undefined;
    sectionDestroy = undefined;
  });

  let linkDestroy, sectionDestroy;

  test("Multiple header actions and links", async function (assert) {
    withPluginApi("1.3.0", (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            get name() {
              return "test-chat-channels";
            }

            get route() {
              return "discovery.latest";
            }

            get title() {
              return "chat channels title";
            }

            get text() {
              return "chat channels text";
            }

            get actionsIcon() {
              return "cog";
            }

            get actions() {
              return [
                {
                  id: "browseChannels",
                  title: "Browse channels",
                  action: () => {},
                },
                {
                  id: "settings",
                  title: "Settings",
                  action: () => {},
                },
              ];
            }

            @bind
            willDestroy() {
              sectionDestroy = "section test";
            }

            get links() {
              return [
                new (class extends BaseCustomSidebarSectionLink {
                  get name() {
                    return "random-channel";
                  }

                  get route() {
                    return "topic";
                  }

                  get models() {
                    return ["some-slug", 1];
                  }

                  get title() {
                    return "random channel title";
                  }

                  get text() {
                    return "random channel text";
                  }

                  get prefixType() {
                    return "icon";
                  }

                  get prefixValue() {
                    return "hashtag";
                  }

                  get prefixColor() {
                    return "FF0000";
                  }

                  get prefixBadge() {
                    return "lock";
                  }

                  get suffixType() {
                    return "icon";
                  }

                  get suffixValue() {
                    return "circle";
                  }

                  get suffixCSSClass() {
                    return "unread";
                  }

                  @bind
                  willDestroy() {
                    linkDestroy = "link test";
                  }
                })(),
                new (class extends BaseCustomSidebarSectionLink {
                  get name() {
                    return "dev-channel";
                  }

                  get route() {
                    return "discovery.latest";
                  }

                  get title() {
                    return "dev channel title";
                  }

                  get text() {
                    return "dev channel text";
                  }

                  get prefixColor() {
                    return "alert";
                  }

                  get prefixType() {
                    return "text";
                  }

                  get prefixValue() {
                    return "test text";
                  }
                })(),
                new (class extends BaseCustomSidebarSectionLink {
                  get name() {
                    return "fun-channel";
                  }

                  get route() {
                    return "discovery.latest";
                  }

                  get title() {
                    return "fun channel title";
                  }

                  get text() {
                    return "fun channel text";
                  }

                  get prefixType() {
                    return "image";
                  }

                  get prefixValue() {
                    return "/test.png";
                  }

                  get hoverType() {
                    return "icon";
                  }

                  get hoverValue() {
                    return "times";
                  }

                  get hoverAction() {
                    return () => {};
                  }

                  get hoverTitle() {
                    return "hover button title attribute";
                  }
                })(),
              ];
            }
          };
        }
      );
    });

    await visit("/");

    assert.strictEqual(
      query(".sidebar-section-test-chat-channels .sidebar-section-header-link")
        .title,
      "chat channels title",
      "displays header with correct title attribute"
    );

    assert.strictEqual(
      query(
        ".sidebar-section-test-chat-channels .sidebar-section-header-link"
      ).textContent.trim(),
      "chat channels text",
      "displays header with correct text"
    );

    await click(
      ".sidebar-section-test-chat-channels .sidebar-section-header-dropdown summary"
    );

    assert.strictEqual(
      queryAll(
        ".sidebar-section-test-chat-channels .sidebar-section-header-dropdown .select-kit-collection li"
      ).length,
      2,
      "displays two actions"
    );

    const actions = queryAll(
      ".sidebar-section-test-chat-channels .sidebar-section-header-dropdown .select-kit-collection li"
    );

    assert.strictEqual(
      actions[0].textContent.trim(),
      "Browse channels",
      "displays first header action with correct text"
    );

    assert.strictEqual(
      actions[1].textContent.trim(),
      "Settings",
      "displays second header action with correct text"
    );

    const links = queryAll(
      ".sidebar-section-test-chat-channels .sidebar-section-link"
    );

    assert.strictEqual(
      links[0].textContent.trim(),
      "random channel text",
      "displays first link with correct text"
    );

    assert.strictEqual(
      links[0].title,
      "random channel title",
      "displays first link with correct title attribute"
    );

    assert.ok(
      links[0].href.endsWith("/some-slug/1"),
      "link has the correct href attribute"
    );

    assert.strictEqual(
      links[0].children.item(0).style.color,
      "rgb(255, 0, 0)",
      "has correct prefix color"
    );

    assert.strictEqual(
      $(links[0].children.item(0).children.item(0)).hasClass("d-icon-hashtag"),
      true,
      "displays prefix icon"
    );

    assert.strictEqual(
      $(links[0].children.item(0).children.item(1)).hasClass("d-icon-lock"),
      true,
      "displays prefix icon badge"
    );

    assert.strictEqual(
      $(links[0].children.item(2).children.item(0)).hasClass("d-icon-circle"),
      true,
      "displays suffix icon"
    );

    assert.strictEqual(
      $(links[1].children[1])[0].textContent.trim(),
      "dev channel text",
      "displays second link with correct text"
    );

    assert.strictEqual(
      links[1].title,
      "dev channel title",
      "displays second link with correct title attribute"
    );

    assert.strictEqual(
      links[1].children.item(0).style.color,
      "",
      "has no color style when value is invalid"
    );

    assert.strictEqual(
      $(links[1].children)[0].textContent.trim(),
      "test text",
      "displays prefix text"
    );

    assert.strictEqual(
      $(links[2].children[1])[0].textContent.trim(),
      "fun channel text",
      "displays third link with correct text"
    );

    assert.strictEqual(
      links[2].title,
      "fun channel title",
      "displays third link with correct title attribute"
    );

    assert.strictEqual(
      $(links[2].children.item(0).children).attr("src"),
      "/test.png",
      "uses correct prefix image url"
    );

    assert.strictEqual(
      query(".sidebar-section-link-hover button").title,
      "hover button title attribute",
      "displays hover button with correct title"
    );

    await undockSidebar();

    assert.strictEqual(
      linkDestroy,
      "link test",
      "calls link willDestroy function"
    );

    assert.strictEqual(
      sectionDestroy,
      "section test",
      "calls section willDestroy function"
    );
  });

  test("Single header action and no links", async function (assert) {
    withPluginApi("1.3.0", (api) => {
      api.addSidebarSection((BaseCustomSidebarSection) => {
        return class extends BaseCustomSidebarSection {
          get name() {
            return "test-chat-channels";
          }

          get route() {
            return "discovery.latest";
          }

          get title() {
            return "chat channels title";
          }

          get text() {
            return "chat channels text";
          }

          get actionsIcon() {
            return "cog";
          }

          get actions() {
            return [
              {
                id: "browseChannels",
                title: "Browse channels",
                action: () => {},
              },
            ];
          }

          get links() {
            return [];
          }
        };
      });
    });

    await visit("/");

    assert.strictEqual(
      query(
        ".sidebar-section-test-chat-channels .sidebar-section-header-link"
      ).textContent.trim(),
      "chat channels text",
      "displays header with correct text"
    );

    assert.ok(
      exists("button.sidebar-section-header-button"),
      "displays single header action button"
    );

    assert.ok(
      !exists(".sidebar-section-test-chat-channels .sidebar-section-content a"),
      "displays no links"
    );
  });
});
