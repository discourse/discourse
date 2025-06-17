import Component from "@glimmer/component";
import { click, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { PLUGIN_API_VERSION, withPluginApi } from "discourse/lib/plugin-api";
import { resetCustomSectionMoreLinks } from "discourse/lib/sidebar/custom-section-more-links";
import {
  resetCustomCategoryLockIcon,
  resetCustomCategorySectionLinkPrefix,
  resetCustomCountables,
} from "discourse/lib/sidebar/user/categories-section/category-section-link";
import { resetCustomTagSectionLinkPrefixIcons } from "discourse/lib/sidebar/user/tags-section/base-tag-section-link";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Sidebar - Plugin API", function (needs) {
  let linkDidInsert, linkDestroy, sectionDestroy;

  needs.user({});

  needs.settings({
    tagging_enabled: true,
    navigation_menu: "sidebar",
  });

  needs.hooks.afterEach(function () {
    linkDidInsert = undefined;
    linkDestroy = undefined;
    sectionDestroy = undefined;
    resetCustomSectionMoreLinks();
  });

  test("Multiple header actions and links", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-chat-channels";
            text = "chat channels text";
            actionsIcon = "gear";
            actions = [
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

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "random-channel";
                classNames = "my-class-name";
                route = "topic";
                models = ["some-slug", 1];
                title = "random channel title";
                text = "random channel text";
                prefixType = "icon";
                prefixValue = "d-chat";
                prefixColor = "FF0000";
                prefixBadge = "lock";
                suffixType = "icon";
                suffixValue = "circle";
                suffixCSSClass = "unread";
                didInsert = () => (linkDidInsert = "link test");
                willDestroy = () => (linkDestroy = "link test");
              })(),
              new (class extends BaseCustomSidebarSectionLink {
                name = "dev-channel";
                route = "discovery.latest";
                title = "dev channel title";
                text = "dev channel text";
                prefixColor = "alert";
                prefixType = "text";
                prefixValue = "test text";
              })(),
              new (class extends BaseCustomSidebarSectionLink {
                name = "fun-channel";
                route = "discovery.latest";
                title = "fun channel title";
                text = "fun channel text";
                prefixType = "image";
                prefixValue = "/test.png";
                hoverType = "icon";
                hoverValue = "xmark";
                hoverAction = () => {};
                hoverTitle = "hover button title attribute";
              })(),
              new (class extends BaseCustomSidebarSectionLink {
                name = "homepage";
                classNames = "my-class-name";
                href = "https://www.discourse.org";
                title = "Homepage";
                text = "Homepage";
              })(),
            ];
            willDestroy = () => (sectionDestroy = "section test");
          };
        }
      );
    });

    await visit("/");

    assert.strictEqual(
      linkDidInsert,
      "link test",
      "calls link didInsert function"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-text"
      )
      .hasText("chat channels text", "displays header with correct text");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-caret"
      )
      .exists();

    await click(
      ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-dropdown summary"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-dropdown .select-kit-collection li"
      )
      .exists({ count: 2 }, "displays two actions");

    const actions = [
      ...document.querySelectorAll(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-dropdown .select-kit-collection li"
      ),
    ];

    assert
      .dom(actions[0])
      .hasText(
        "Browse channels",
        "displays first header action with correct text"
      );

    assert
      .dom(actions[1])
      .hasText("Settings", "displays second header action with correct text");

    const links = [
      ...document.querySelectorAll(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-link"
      ),
    ];

    assert
      .dom(links[0])
      .hasText("random channel text", "displays first link with correct text");

    assert
      .dom(".sidebar-section-link.my-class-name")
      .exists("sets the custom class name for the section link");

    assert
      .dom(links[0])
      .hasAttribute(
        "title",
        "random channel title",
        "displays first link with correct title attribute"
      );

    assert
      .dom(links[0])
      .hasAttribute(
        "href",
        "/t/some-slug/1",
        "link has the correct href attribute"
      );

    assert
      .dom(links[0].children[0])
      .hasStyle({ color: "rgb(255, 0, 0)" }, "has correct prefix color");

    assert
      .dom(links[0].children[0].children[0])
      .hasClass("d-icon-d-chat", "displays prefix icon");

    assert
      .dom(links[0].children[0].children[1])
      .hasClass("d-icon-lock", "displays prefix icon badge");

    assert
      .dom(links[0].children[2].children[0])
      .hasClass("d-icon-circle", "displays suffix icon");

    assert
      .dom(links[1].children[1])
      .hasText("dev channel text", "displays second link with correct text");

    assert
      .dom(links[1])
      .hasAttribute(
        "title",
        "dev channel title",
        "displays second link with correct title attribute"
      );

    assert
      .dom(links[1].children[0])
      .hasNoAttribute("style", "has no color style when value is invalid");

    assert
      .dom(links[1].children[0])
      .hasText("test text", "displays prefix text");

    assert
      .dom(links[2].children[1])
      .hasText("fun channel text", "displays third link with correct text");

    assert
      .dom(links[2])
      .hasAttribute(
        "title",
        "fun channel title",
        "displays third link with correct title attribute"
      );

    assert
      .dom(links[2].children[0].children[0])
      .hasAttribute("src", "/test.png", "uses correct prefix image url");

    assert
      .dom(links[3])
      .hasAttribute(
        "title",
        "Homepage",
        "displays external link with correct title attribute"
      );

    assert
      .dom(links[3])
      .hasAttribute(
        "href",
        "https://www.discourse.org",
        "displays external link with correct href attribute"
      );

    assert
      .dom(".sidebar-section-link-hover button")
      .hasAttribute(
        "title",
        "hover button title attribute",
        "displays hover button with correct title"
      );

    await click(".btn-sidebar-toggle");

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
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection((BaseCustomSidebarSection) => {
        return class extends BaseCustomSidebarSection {
          name = "test-chat-channels";
          text = "chat channels text";
          actionsIcon = "gear";
          actions = [
            {
              id: "browseChannels",
              title: "Browse channels",
              action: () => {},
            },
          ];
          links = [];
        };
      });
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-text"
      )
      .hasText("chat channels text", "displays header with correct text");

    assert
      .dom("button.sidebar-section-header-button")
      .exists("displays single header action button");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-content a"
      )
      .doesNotExist("displays no links");
  });

  test("Empty state when no links are present", async function (assert) {
    const emptyStateComponent = class EmptyStateTestComponent extends Component {
      <template>
        <div class="test-empty-state">Empty</div>
      </template>
    };

    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection((BaseCustomSidebarSection) => {
        return class extends BaseCustomSidebarSection {
          name = "test-empty-state";
          text = "random text";
          links = [];

          get emptyStateComponent() {
            return emptyStateComponent;
          }
        };
      });
    });
    await visit("/");
    assert
      .dom(
        ".sidebar-section[data-section-name='test-empty-state'] #sidebar-section-content-test-empty-state .test-empty-state"
      )
      .hasText("Empty");
  });

  test("Section that is not displayed via displaySection", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection((BaseCustomSidebarSection) => {
        return class extends BaseCustomSidebarSection {
          name = "test-chat-channels";
          text = "chat channels text";
          actionsIcon = "gear";
          actions = [
            {
              id: "browseChannels",
              title: "Browse channels",
              action: () => {},
            },
          ];
          links = [];
          displaySection = false;
        };
      });
    });

    await visit("/");

    assert
      .dom(".sidebar-section[data-section-name='test-chat-channels']")
      .doesNotExist("does not display the section");
  });

  test("Registering a custom countable for a section link in the user's sidebar categories section", async function (assert) {
    try {
      return await withPluginApi(PLUGIN_API_VERSION, async (api) => {
        const { categories } = this.container.lookup("service:site");
        const category1 = categories[0];
        const category2 = categories[1];

        updateCurrentUser({
          sidebar_category_ids: [category1.id, category2.id],
        });

        // User has one unread topic
        this.container.lookup("service:topic-tracking-state").loadStates([
          {
            topic_id: 2,
            highest_post_number: 12,
            last_read_post_number: 11,
            created_at: "2020-02-09T09:40:02.672Z",
            category_id: category1.id,
            notification_level: 2,
            created_in_new_period: false,
            treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
          },
        ]);

        api.registerUserCategorySectionLinkCountable({
          badgeTextFunction: (count) => `some custom ${count}`,
          route: "discovery.latestCategory",
          routeQuery: { status: "open" },
          shouldRegister: ({ category }) => {
            if (category.displayName === category1.displayName) {
              return true;
            } else if (category.displayName === category2.displayName) {
              return false;
            }
          },
          refreshCountFunction: ({ category }) => category.topic_count,
          prioritizeOverDefaults: ({ category }) => category.topic_count > 1000,
        });

        await visit("/");

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-suffix.unread`
          )
          .exists(
            "the right suffix is displayed when custom countable is active"
          );

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a`
          )
          .hasProperty(
            "pathname",
            `/c/${category1.name}/${category1.id}`,
            "does not use route configured for custom countable when user has elected not to show any counts in sidebar"
          );

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-category-id="${category2.id}"] .sidebar-section-link-suffix.unread`
          )
          .doesNotExist(
            "does not display suffix when custom countable is not registered"
          );

        updateCurrentUser({
          user_option: {
            sidebar_link_to_filtered_list: true,
            sidebar_show_count_of_new_items: true,
          },
        });

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-content-badge`
          )
          .hasText(
            i18n("sidebar.unread_count", { count: 1 }),
            "displays the right badge text in section link when unread is present and custom countable is not prioritised over unread"
          );

        category1.set("topic_count", 2000);

        api.refreshUserSidebarCategoriesSectionCounts();

        await settled();

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-content-badge`
          )
          .hasText(
            `some custom ${category1.topic_count}`,
            "displays the right badge text in section link when unread is present but custom countable is prioritised over unread"
          );

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a`
          )
          .hasProperty(
            "pathname",
            `/c/${category1.name}/${category1.id}/l/latest`,
            "has the right pathname for section link"
          );

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a`
          )
          .hasProperty(
            "search",
            "?status=open",
            "has the right query params for section link"
          );
      });
    } finally {
      resetCustomCountables();
    }
  });

  test("Customizing the icon used in a category section link to indicate that a category is read restricted", async function (assert) {
    try {
      return await withPluginApi(PLUGIN_API_VERSION, async (api) => {
        const { categories } = this.container.lookup("service:site");
        const category1 = categories[0];
        category1.read_restricted = true;

        updateCurrentUser({
          sidebar_category_ids: [category1.id],
        });

        api.registerCustomCategorySectionLinkLockIcon("wrench");

        await visit("/");

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .prefix-badge.d-icon-wrench`
          )
          .exists(
            "wrench icon is displayed for the section link's prefix badge"
          );
      });
    } finally {
      resetCustomCategoryLockIcon();
    }
  });

  test("Customizing the prefix used in a category section link for a particular category", async function (assert) {
    try {
      return await withPluginApi(PLUGIN_API_VERSION, async (api) => {
        const { categories } = this.container.lookup("service:site");
        const category1 = categories[0];
        category1.read_restricted = true;

        updateCurrentUser({
          sidebar_category_ids: [category1.id],
        });

        api.registerCustomCategorySectionLinkPrefix({
          categoryId: category1.id,
          prefixType: "icon",
          prefixValue: "wrench",
          prefixColor: "FF0000", // rgb(255, 0, 0)
        });

        await visit("/");

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .prefix-icon.d-icon-wrench`
          )
          .exists(
            "wrench icon is displayed for the section link's prefix icon"
          );

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-prefix`
          )
          .hasStyle(
            { color: "rgb(255, 0, 0)" },
            "section link's prefix icon has the right color"
          );
      });
    } finally {
      resetCustomCategorySectionLinkPrefix();
    }
  });

  test("Customizing the prefix icon used in a tag section link for a particular tag", async function (assert) {
    try {
      return await withPluginApi(PLUGIN_API_VERSION, async (api) => {
        updateCurrentUser({
          display_sidebar_tags: true,
          sidebar_tags: [
            { name: "tag2", pm_only: false },
            { name: "tag1", pm_only: false },
            { name: "tag3", pm_only: false },
          ],
        });

        api.registerCustomTagSectionLinkPrefixIcon({
          tagName: "tag1",
          prefixValue: "wrench",
          prefixColor: "#FF0000", // rgb(255, 0, 0)
        });

        await visit("/");

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-tag-name="tag1"] .prefix-icon.d-icon-wrench`
          )
          .exists(
            "wrench icon is displayed for tag1 section link's prefix icon"
          );

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-tag-name="tag1"] .sidebar-section-link-prefix`
          )
          .hasStyle(
            { color: "rgb(255, 0, 0)" },
            "tag1 section link's prefix icon has the right color"
          );

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-tag-name="tag2"] .prefix-icon.d-icon-tag`
          )
          .exists(
            "default tag icon is displayed for tag2 section link's prefix icon"
          );
      });
    } finally {
      resetCustomTagSectionLinkPrefixIcons();
    }
  });

  test("New custom sidebar panel and option to set default and show/hide switch buttons", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarPanel((BaseCustomSidebarPanel) => {
        const ChatSidebarPanel = class extends BaseCustomSidebarPanel {
          key = "new-panel";
          switchButtonLabel = "New panel";
          switchButtonIcon = "d-chat";
          switchButtonDefaultUrl = "/chat";
        };
        return ChatSidebarPanel;
      });
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-chat-channels";
            text = "chat channels text";
            actionsIcon = "gear";
            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "random-channel";
                classNames = "my-class-name";
                route = "topic";
                models = ["some-slug", 1];
                title = "random channel title";
                text = "random channel text";
                prefixType = "icon";
                prefixValue = "d-chat";
                prefixColor = "FF0000";
                prefixBadge = "lock";
                suffixType = "icon";
                suffixValue = "circle";
                suffixCSSClass = "unread";
              })(),
            ];
          };
        },
        "new-panel"
      );
      api.setSeparatedSidebarMode();
      api.setSidebarPanel("new-panel");
      api.setSeparatedSidebarMode();
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-text"
      )
      .hasText("chat channels text", "displays header with correct text");

    await click(".sidebar__panel-switch-button");

    assert
      .dom(".sidebar-section[data-section-name='test-chat-channels']")
      .doesNotExist();
    assert.dom(".sidebar-sections + button").exists();

    assert
      .dom("#d-sidebar .sidebar-sections + .sidebar__panel-switch-button")
      .exists();
    assert
      .dom("#d-sidebar .sidebar__panel-switch-button + .sidebar-sections")
      .doesNotExist();

    this.siteSettings.default_sidebar_switch_panel_position = "top";
    await visit("/");

    assert
      .dom("#d-sidebar .sidebar-sections + .sidebar__panel-switch-button")
      .doesNotExist();
    assert
      .dom("#d-sidebar .sidebar__panel-switch-button + .sidebar-sections")
      .exists();

    assert
      .dom(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-text"
      )
      .doesNotExist();

    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.setCombinedSidebarMode();
    });

    await visit("/");
    assert.dom(".sidebar__panel-switch-button").doesNotExist();

    assert
      .dom(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-text"
      )
      .exists();

    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.setSidebarPanel("new-panel");
      api.hideSidebarSwitchPanelButtons();
    });

    await visit("/");
    assert.dom(".sidebar__panel-switch-button").doesNotExist();

    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.setSidebarPanel("new-panel");
      api.hideSidebarSwitchPanelButtons();
      api.showSidebarSwitchPanelButtons();
    });

    await visit("/");
    assert.dom(".sidebar__panel-switch-button").exists();
  });

  test("New hidden custom sidebar panel", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarPanel((BaseCustomSidebarPanel) => {
        const AdminSidebarPanel = class extends BaseCustomSidebarPanel {
          key = "admin";
          hidden = true;
        };
        return AdminSidebarPanel;
      });
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-admin-section";
            text = "test admin section";
            actionsIcon = "gear";
            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "admin-link";
                classNames = "my-class-name";
                route = "topic";
                models = ["some-slug", 1];
                title = "admin link";
                text = "admin link";
                prefixType = "icon";
                prefixValue = "gear";
                prefixColor = "FF0000";
                prefixBadge = "lock";
                suffixType = "icon";
                suffixValue = "circle";
                suffixCSSClass = "unread";
              })(),
            ];
          };
        },
        "admin"
      );
      api.setSidebarPanel("admin");
      api.setSeparatedSidebarMode();
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-admin-section'] .sidebar-section-header-text"
      )
      .hasText("test admin section", "displays header with correct text");
    assert.dom(".admin-panel").exists();

    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.setSidebarPanel("main-panel");
      api.setCombinedSidebarMode();
    });

    await visit("/");
    assert.dom(".sidebar__panel-switch-button").doesNotExist();
    assert.dom(".admin-panel").doesNotExist();
    assert
      .dom(".sidebar-section[data-section-name='test-admin-section']")
      .doesNotExist();
  });

  test("Auto expand active sections", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarPanel((BaseCustomSidebarPanel) => {
        return class extends BaseCustomSidebarPanel {
          key = "new-panel";
          expandActiveSection = true;
        };
      });
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-section-1";
            text = "The First Section";
            collapsedByDefault = true;
            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "test-link-1";
                href = "/test1";
                title = "Test Link Title 1";
                text = "Test Link Text 1";
              })(),
            ];
          };
        },
        "new-panel"
      );
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-section-2";
            text = "The Second Section";
            collapsedByDefault = true;
            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "search";
                route = "full-page-search";
                title = "Search";
                text = "Search";
              })(),
            ];
          };
        },
        "new-panel"
      );
      api.setSeparatedSidebarMode();
      api.setSidebarPanel("new-panel");
    });

    await visit("/");
    assert.dom(".sidebar-section.sidebar-section--expanded").doesNotExist();

    await visit("/search");
    assert
      .dom(
        "div[data-section-name='test-section-2'].sidebar-section.sidebar-section--expanded"
      )
      .exists({ count: 1 });
  });

  test("Scroll active link into view", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarPanel((BaseCustomSidebarPanel) => {
        return class extends BaseCustomSidebarPanel {
          key = "new-panel";
          expandActiveSection = true;
          scrollActiveLinkIntoView = true;
        };
      });
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = `test-section-1`;
            text = "The Section";
            collapsedByDefault = false;

            get links() {
              const values = [...Array(100)].map(
                (_, i) =>
                  new (class extends BaseCustomSidebarSectionLink {
                    get name() {
                      return `test-link-${i}`;
                    }

                    get href() {
                      return `/test${i}`;
                    }

                    get title() {
                      return `Test Link Title ${i}`;
                    }

                    get text() {
                      return `Test Link Text ${i}`;
                    }
                  })()
              );

              values.push(
                new (class extends BaseCustomSidebarSectionLink {
                  name = "search";
                  route = "full-page-search";
                  title = "Search";
                  text = "Search";
                })()
              );

              return values;
            }
          };
        },
        "new-panel"
      );
      api.setSeparatedSidebarMode();
      api.setSidebarPanel("new-panel");
    });

    await visit("/");
    const sidebarHeight =
      document.querySelector(".sidebar-wrapper").clientHeight;
    const searchLinkOffsetTop = document.querySelector(
      ".sidebar-section-link-wrapper[data-list-item-name='search']"
    ).offsetTop;

    assert.true(
      searchLinkOffsetTop > sidebarHeight,
      "the link offsetTop is greater than the sidebar height"
    );
    assert
      .dom(".sidebar-sections")
      .hasProperty("scrollTop", 0, "the sidebar is not scrolled initially");

    await visit("/search");
    assert
      .dom(
        ".sidebar-section-link-wrapper[data-list-item-name='search'] > a.active"
      )
      .exists();

    const sidebarScrollTop =
      document.querySelector(".sidebar-sections").scrollTop;
    assert.true(
      sidebarScrollTop > 0,
      "the sidebar was scrolled to position the active element into view"
    );
    assert.true(
      searchLinkOffsetTop < sidebarScrollTop + sidebarHeight,
      "the link is into view"
    );
  });

  test("Section with more links dropdown", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-section-with-more";
            text = "Section with More";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "main-link";
                route = "discovery.latest";
                title = "Main Link";
                text = "Main Link";
                prefixType = "icon";
                prefixValue = "star";
              })(),
            ];

            moreLinks = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "more-link-1";
                route = "discovery.top";
                title = "Top Topics";
                text = "Top Topics";
                prefixType = "icon";
                prefixValue = "trophy";
              })(),
              new (class extends BaseCustomSidebarSectionLink {
                name = "more-link-2";
                href = "https://example.com";
                title = "External Link";
                text = "External Link";
                prefixType = "icon";
                prefixValue = "external-link-alt";
              })(),
            ];

            get moreSectionText() {
              return "Customize";
            }

            get moreSectionIcon() {
              return "cog";
            }
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-section-with-more'] a.sidebar-section-link"
      )
      .exists({ count: 1 }, "displays main section link");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-section-with-more'] a.sidebar-section-link"
      )
      .hasText("Main Link", "displays main link with correct text");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-section-with-more'] .sidebar-more-section-links-details-summary"
      )
      .exists("displays more section trigger");

    await click(
      ".sidebar-section[data-section-name='test-section-with-more'] .sidebar-more-section-links-details-summary"
    );

    const moreLinks = [
      ...document.querySelectorAll(
        ".sidebar-section[data-section-name='test-section-with-more'] .dropdown-menu__item"
      ),
    ];

    assert.strictEqual(
      moreLinks.length,
      2,
      "displays correct number of more links"
    );

    assert
      .dom(moreLinks[0])
      .hasText("Top Topics", "displays first more link with correct text");

    assert
      .dom(moreLinks[1])
      .hasText("External Link", "displays second more link with correct text");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-section-with-more'] .--link-button"
      )
      .exists("displays custom more section button");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-section-with-more'] .--link-button"
      )
      .hasText("Customize", "displays custom button with correct text");
  });

  test("Adding more links to existing section via API", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-extensible-section";
            text = "Extensible Section";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "main-link";
                route = "discovery.latest";
                title = "Main Link";
                text = "Main Link";
              })(),
            ];
          };
        }
      );

      // Add more links via API
      api.addCustomSectionMoreLink("test-extensible-section", {
        name: "api-more-link-1",
        route: "discovery.top",
        title: "Top Topics",
        text: "Top Topics",
        icon: "trophy",
      });

      api.addCustomSectionMoreLink("test-extensible-section", {
        name: "api-more-link-2",
        href: "https://meta.discourse.org",
        title: "Meta Discourse",
        text: "Meta Discourse",
        icon: "external-link-alt",
      });

      api.addCustomSectionMoreLink(
        "test-extensible-section",
        (BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSectionLink {
            name = "callback-more-link";
            route = "badges";
            title = "Badges";
            text = "Badges";
            prefixType = "icon";
            prefixValue = "certificate";
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-extensible-section'] [data-link-name]"
      )
      .exists({ count: 1 }, "displays main section link");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-extensible-section'] .sidebar-more-section-links-details-summary"
      )
      .exists("displays more section trigger");

    await click(
      ".sidebar-section[data-section-name='test-extensible-section'] .sidebar-more-section-links-details-summary"
    );

    const moreLinks = [
      ...document.querySelectorAll(
        ".sidebar-section[data-section-name='test-extensible-section'] .dropdown-menu__item"
      ),
    ];

    assert.strictEqual(
      moreLinks.length,
      3,
      "displays all API-added more links"
    );

    assert
      .dom(moreLinks[0])
      .hasText("Top Topics", "displays first API more link");

    assert
      .dom(moreLinks[1])
      .hasText("Meta Discourse", "displays second API more link");

    assert
      .dom(moreLinks[2])
      .hasText("Badges", "displays callback-based more link");
  });
});

acceptance("Sidebar - Plugin API - Anonymous", function (needs) {
  needs.settings({
    navigation_menu: "sidebar",
  });

  needs.hooks.afterEach(function () {
    resetCustomSectionMoreLinks();
  });

  test("More links work for anonymous users", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-anonymous-more";
            text = "Anonymous More Section";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "main-link";
                route = "discovery.latest";
                title = "Latest";
                text = "Latest";
              })(),
            ];

            moreLinks = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "more-categories";
                route = "badges";
                title = "Badges";
                text = "Badges";
                prefixType = "icon";
                prefixValue = "list";
              })(),
            ];
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-anonymous-more'] .sidebar-section-header-text"
      )
      .hasText("Anonymous More Section", "displays section for anonymous user");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-anonymous-more'] .sidebar-more-section-links-details-summary"
      )
      .exists("displays more dropdown for anonymous user");

    await click(
      ".sidebar-section[data-section-name='test-anonymous-more'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='test-anonymous-more'] .dropdown-menu__item"
      )
      .hasText("Badges", "displays more link for anonymous user");
  });

  test("Custom more button text and icon", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-custom-more";
            text = "Custom More Section";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "main-link";
                route = "discovery.latest";
                title = "Latest";
                text = "Latest";
              })(),
            ];

            moreLinks = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "more-categories";
                route = "badges";
                title = "Badges";
                text = "Badges";
              })(),
            ];

            get moreSectionText() {
              return "Show All";
            }

            get moreSectionIcon() {
              return "plus";
            }
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-custom-more'] .sidebar-more-section-links-details-summary .sidebar-section-link-content-text"
      )
      .hasText("Show All", "displays custom more button text");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-custom-more'] .sidebar-more-section-links-details-summary .d-icon-plus"
      )
      .exists("displays custom more button icon");
  });

  test("Default more button text and icon when none provided", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-default-more";
            text = "Default More Section";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "main-link";
                route = "discovery.latest";
                title = "Latest";
                text = "Latest";
              })(),
            ];

            moreLinks = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "more-categories";
                route = "badges";
                title = "Badges";
                text = "Badges";
              })(),
            ];
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-default-more'] .sidebar-more-section-links-details-summary .d-icon-ellipsis-vertical"
      )
      .exists("displays default more button icon");
  });

  test("Custom more button text only (default icon)", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-custom-text-only";
            text = "Custom Text Only Section";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "main-link";
                route = "discovery.latest";
                title = "Latest";
                text = "Latest";
              })(),
            ];

            moreLinks = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "more-categories";
                route = "badges";
                title = "Badges";
                text = "Badges";
              })(),
            ];

            get moreSectionText() {
              return "View More";
            }
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-custom-text-only'] .sidebar-more-section-links-details-summary .sidebar-section-link-content-text"
      )
      .hasText("View More", "displays custom more button text");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-custom-text-only'] .sidebar-more-section-links-details-summary .d-icon-ellipsis-vertical"
      )
      .exists("displays default more button icon when only text customized");
  });

  test("Custom more button icon only (default text)", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-custom-icon-only";
            text = "Custom Icon Only Section";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "main-link";
                route = "discovery.latest";
                title = "Latest";
                text = "Latest";
              })(),
            ];

            moreLinks = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "more-categories";
                route = "badges";
                title = "Badges";
                text = "Badges";
              })(),
            ];

            get moreSectionIcon() {
              return "chevron-down";
            }
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-custom-icon-only'] .sidebar-more-section-links-details-summary .d-icon-chevron-down"
      )
      .exists("displays custom more button icon");
  });

  test("Custom more button with complex scenarios", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-complex-more";
            text = "Complex More Section";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "main-link";
                route = "discovery.latest";
                title = "Latest";
                text = "Latest";
              })(),
            ];

            moreLinks = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "more-categories";
                route = "badges";
                title = "Badges";
                text = "Badges";
              })(),
            ];

            get moreSectionButtonAction() {
              return () => {};
            }

            get moreSectionButtonText() {
              return "Settings";
            }

            get moreSectionButtonIcon() {
              return "cog";
            }

            get moreSectionText() {
              return "More Options";
            }

            get moreSectionIcon() {
              return "bars";
            }
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-complex-more'] .sidebar-more-section-links-details-summary .sidebar-section-link-content-text"
      )
      .hasText("More Options", "displays custom more dropdown text");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-complex-more'] .sidebar-more-section-links-details-summary .d-icon-bars"
      )
      .exists("displays custom more dropdown icon");

    await click(
      ".sidebar-section[data-section-name='test-complex-more'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='test-complex-more'] .dropdown-menu__item"
      )
      .exists("displays more links in dropdown");

    assert
      .dom(".dropdown-menu__item button.--link-button")
      .hasText("Settings", "displays more section button");
  });
});
