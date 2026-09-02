import Component from "@glimmer/component";
import { click, fillIn, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
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
  });

  test("Multiple header actions and links", async function (assert) {
    withPluginApi((api) => {
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
                hoverType = "icon";
                hoverValue = "trash-can";
                hoverAction = () => {};
                hoverTitle = "href hover button title";
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
      ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-dropdown"
    );

    assert
      .dom(".sidebar-section-header-dropdown__item")
      .exists({ count: 2 }, "displays two actions");

    const actions = [
      ...document.querySelectorAll(".sidebar-section-header-dropdown__item"),
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
      .dom(
        ".sidebar-section-link[data-link-name='fun-channel'] .sidebar-section-link-hover button"
      )
      .hasAttribute(
        "title",
        "hover button title attribute",
        "displays hover button for route link"
      );

    assert
      .dom(
        ".sidebar-section-link[data-link-name='homepage'] .sidebar-section-link-hover button"
      )
      .hasAttribute(
        "title",
        "href hover button title",
        "displays hover button for href link"
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

  test("A section without moreLinks renders no drawer", async function (assert) {
    withPluginApi((api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-plain-section";
            text = "plain section text";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "plain-link";
                route = "discovery.latest";
                title = "plain link title";
                text = "plain link text";
              })(),
            ];
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(".sidebar-section[data-section-name='test-plain-section']")
      .exists();

    assert
      .dom(
        ".sidebar-section[data-section-name='test-plain-section'] .sidebar-more-section-links-details-summary"
      )
      .doesNotExist("no drawer trigger is added to sections that opt out");
  });

  test("Links behind a more drawer", async function (assert) {
    withPluginApi((api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-inboxes";
            text = "inboxes text";
            moreLinksTriggerText = "Pick an inbox";
            moreLinksTriggerPrefixType = "icon";
            moreLinksTriggerPrefixValue = "inbox";
            moreLinksTriggerSuffixType = "icon";
            moreLinksTriggerSuffixValue = "chevron-down";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "always-shown";
                route = "discovery.latest";
                title = "always shown title";
                text = "always shown text";
              })(),
            ];

            moreLinks = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "tucked-away";
                route = "discovery.unread";
                title = "tucked away title";
                text = "tucked away text";
              })(),
            ];
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(".sidebar-section[data-section-name='test-inboxes']")
      .exists("the section is rendered");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-inboxes'] [data-link-name='tucked-away']"
      )
      .doesNotExist("drawer links are not rendered inline");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-inboxes'] .sidebar-more-section-links-details-summary"
      )
      .hasText("Pick an inbox", "the trigger uses the section's text");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-inboxes'] .sidebar-section-link-prefix .d-icon-inbox"
      )
      .exists("the trigger takes a prefix like a section link does");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-inboxes'] .sidebar-section-link-suffix .d-icon-chevron-down"
      )
      .exists("and a suffix");

    await click(
      ".sidebar-section[data-section-name='test-inboxes'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom("[data-link-name='tucked-away']")
      .exists("the drawer reveals its links");
  });

  test("A more drawer copes with links that only carry an href", async function (assert) {
    withPluginApi((api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-href-drawer";
            text = "href drawer text";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "always-shown";
                route = "discovery.latest";
                title = "always shown title";
                text = "always shown text";
              })(),
            ];

            moreLinks = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "external";
                href = "https://www.discourse.org";
                title = "External";
                text = "External";
              })(),
            ];
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-href-drawer'] .sidebar-more-section-links-details-summary"
      )
      .exists("the section renders rather than throwing");

    await click(
      ".sidebar-section[data-section-name='test-href-drawer'] .sidebar-more-section-links-details-summary"
    );

    assert
      .dom("[data-link-name='external']")
      .exists("and the href-only link is listed");
  });

  test("A more drawer can be inlined by the section", async function (assert) {
    withPluginApi((api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-inlined-drawer";
            text = "inlined drawer text";
            moreLinksInline = true;

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "always-shown";
                route = "discovery.latest";
                title = "always shown title";
                text = "always shown text";
              })(),
            ];

            moreLinks = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "listed-inline";
                route = "discovery.unread";
                title = "listed inline title";
                text = "listed inline text";
              })(),
            ];
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-inlined-drawer'] [data-link-name='listed-inline']"
      )
      .exists("the links are rendered in the section");

    assert
      .dom(
        ".sidebar-section[data-section-name='test-inlined-drawer'] .sidebar-more-section-links-details-summary"
      )
      .doesNotExist("and there is no trigger to open");
  });

  test("A more drawer can lead the section", async function (assert) {
    withPluginApi((api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-leading-drawer";
            text = "leading drawer text";
            moreLinksPosition = "start";

            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "second-item";
                route = "discovery.latest";
                title = "second item title";
                text = "second item text";
              })(),
            ];

            moreLinks = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "in-the-drawer";
                route = "discovery.unread";
                title = "in the drawer title";
                text = "in the drawer text";
              })(),
            ];
          };
        }
      );
    });

    await visit("/");

    const rows = [
      ...document.querySelectorAll(
        ".sidebar-section[data-section-name='test-leading-drawer'] .sidebar-section-link-wrapper"
      ),
    ];

    assert.dom(rows[0]).hasText("More", "the drawer trigger is the first row");
  });

  test("Single header action and no links", async function (assert) {
    withPluginApi((api) => {
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

    withPluginApi((api) => {
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
    withPluginApi((api) => {
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
      return await withPluginApi(async (api) => {
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
      return await withPluginApi(async (api) => {
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
      return await withPluginApi(async (api) => {
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
      return await withPluginApi(async (api) => {
        updateCurrentUser({
          display_sidebar_tags: true,
          sidebar_tags: [
            { id: 2, name: "tag2", slug: "tag2", pm_only: false },
            { id: 1, name: "tag1", slug: "tag1", pm_only: false },
            { id: 3, name: "tag3", slug: "tag3", pm_only: false },
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

  test("Customizing the prefix icon used in a tag section link by tag slug", async function (assert) {
    try {
      return await withPluginApi(async (api) => {
        updateCurrentUser({
          display_sidebar_tags: true,
          sidebar_tags: [
            { id: 1, name: "tag_1", slug: "tag-1", pm_only: false },
            { id: 2, name: "tag_2", slug: "tag-2", pm_only: false },
          ],
        });

        api.registerCustomTagSectionLinkPrefixIcon({
          tagName: "tag-1",
          prefixValue: "wrench",
        });

        await visit("/");

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-tag-name="tag_1"] .prefix-icon.d-icon-wrench`
          )
          .exists("wrench icon is displayed when matching on the tag's slug");

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-tag-name="tag_2"] .prefix-icon.d-icon-tag`
          )
          .exists("default tag icon is displayed for the unconfigured tag");
      });
    } finally {
      resetCustomTagSectionLinkPrefixIcons();
    }
  });

  test("Customizing the prefix icon used in a tag section link by untranslated tag name", async function (assert) {
    try {
      return await withPluginApi(async (api) => {
        updateCurrentUser({
          display_sidebar_tags: true,
          sidebar_tags: [
            {
              id: 1,
              name: "戦略",
              slug: "strategic-access",
              original_name: "strategic_access",
              pm_only: false,
            },
          ],
        });

        api.registerCustomTagSectionLinkPrefixIcon({
          tagName: "strategic_access",
          prefixValue: "wrench",
        });

        await visit("/");

        assert
          .dom(
            `.sidebar-section-link-wrapper[data-tag-name="strategic_access"] .prefix-icon.d-icon-wrench`
          )
          .exists(
            "wrench icon is displayed when matching on the tag's untranslated name"
          );
      });
    } finally {
      resetCustomTagSectionLinkPrefixIcons();
    }
  });

  test("New custom sidebar panel and option to set default and show/hide switch buttons", async function (assert) {
    withPluginApi((api) => {
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

    withPluginApi((api) => {
      api.setCombinedSidebarMode();
    });

    await visit("/");
    assert.dom(".sidebar__panel-switch-button").doesNotExist();

    assert
      .dom(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-text"
      )
      .exists();

    withPluginApi((api) => {
      api.setSidebarPanel("new-panel");
      api.hideSidebarSwitchPanelButtons();
    });

    await visit("/");
    assert.dom(".sidebar__panel-switch-button").doesNotExist();

    withPluginApi((api) => {
      api.setSidebarPanel("new-panel");
      api.hideSidebarSwitchPanelButtons();
      api.showSidebarSwitchPanelButtons();
    });

    await visit("/");
    assert.dom(".sidebar__panel-switch-button").exists();
  });

  test("New hidden custom sidebar panel", async function (assert) {
    withPluginApi((api) => {
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

    withPluginApi((api) => {
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
    withPluginApi((api) => {
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

  test("Scroll active link into view on first load, for a short section below long ones", async function (assert) {
    withPluginApi((api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-long-section";
            text = "Long";
            collapsedByDefault = false;

            get links() {
              return [...Array(100)].map(
                (_, i) =>
                  new (class extends BaseCustomSidebarSectionLink {
                    get name() {
                      return `filler-${i}`;
                    }

                    get href() {
                      return `/filler${i}`;
                    }

                    get title() {
                      return `Filler ${i}`;
                    }

                    get text() {
                      return `Filler ${i}`;
                    }
                  })()
              );
            }
          };
        }
      );

      // its own single-link section, rendered after the long one
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-trailing-section";
            hideSectionHeader = true;
            text = null;

            get links() {
              return [
                new (class extends BaseCustomSidebarSectionLink {
                  name = "trailing-search";
                  route = "full-page-search";
                  title = "Search";
                  text = "Search";
                })(),
              ];
            }
          };
        }
      );
    });

    // land on the page directly rather than transitioning to it
    await visit("/search");

    assert
      .dom(
        ".sidebar-section-link-wrapper[data-list-item-name='trailing-search'] > a.active"
      )
      .exists("precondition: the link is detected as active");

    assert.true(
      document.querySelector(".sidebar-sections").scrollTop > 0,
      "the sidebar scrolled the trailing section's link into view on load"
    );
  });

  test("Scroll active link into view for a section in the main sidebar", async function (assert) {
    // Sections can be appended to the main sidebar rather than living in a
    // panel of their own; those render through ApiSections inside the main
    // panel, so the main panel's flag has to reach them.
    withPluginApi((api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-appended-section";
            text = "Appended";
            collapsedByDefault = false;

            get links() {
              const values = [...Array(100)].map(
                (_, i) =>
                  new (class extends BaseCustomSidebarSectionLink {
                    get name() {
                      return `appended-link-${i}`;
                    }

                    get href() {
                      return `/appended${i}`;
                    }

                    get title() {
                      return `Appended Link ${i}`;
                    }

                    get text() {
                      return `Appended Link ${i}`;
                    }
                  })()
              );

              values.push(
                new (class extends BaseCustomSidebarSectionLink {
                  name = "appended-search";
                  route = "full-page-search";
                  title = "Search";
                  text = "Search";
                })()
              );

              return values;
            }
          };
        }
      );
    });

    await visit("/");

    assert
      .dom(".sidebar-sections")
      .hasProperty("scrollTop", 0, "the sidebar is not scrolled initially");

    await visit("/search");

    assert
      .dom(
        ".sidebar-section-link-wrapper[data-list-item-name='appended-search'] > a.active"
      )
      .exists();

    assert.true(
      document.querySelector(".sidebar-sections").scrollTop > 0,
      "the main sidebar scrolled the appended section's active link into view"
    );
  });

  test("Scroll active link into view", async function (assert) {
    withPluginApi((api) => {
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

  test("filtering does not crash when a custom sidebar section link has no keywords getter", async function (assert) {
    withPluginApi((api) => {
      api.addSidebarPanel((BaseCustomSidebarPanel) => {
        return class extends BaseCustomSidebarPanel {
          key = "filterable-panel";
          switchButtonLabel = "Filterable panel";
          switchButtonIcon = "d-chat";
          switchButtonDefaultUrl = "/";
          displayHeader = true;

          get filterable() {
            return true;
          }
        };
      });

      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            name = "test-section";
            text = "test section text";
            links = [
              new (class extends BaseCustomSidebarSectionLink {
                name = "test-link";
                href = "/";
                title = "Test Link";
                text = "Test Link Text";
              })(),
            ];
          };
        },
        "filterable-panel"
      );

      api.setSeparatedSidebarMode();
      api.setSidebarPanel("filterable-panel");
    });

    await visit("/");

    assert
      .dom(".sidebar-filter__input")
      .exists("filter input is visible for filterable panel");

    // Use a filter that doesn't match the link text so keywords.navigation is accessed
    await fillIn(".sidebar-filter__input", "nomatch");

    assert
      .dom(".sidebar-section-link-wrapper[data-list-item-name='test-link']")
      .doesNotExist(
        "section link is filtered out (no crash accessing keywords)"
      );
  });
});
