import { test } from "qunit";
import I18n from "I18n";
import { click, settled, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { withPluginApi } from "discourse/lib/plugin-api";
import Site from "discourse/models/site";
import { resetCustomCountables } from "discourse/lib/sidebar/user/categories-section/category-section-link";
import { UNREAD_LIST_DESTINATION } from "discourse/controllers/preferences/sidebar";
import { bind } from "discourse-common/utils/decorators";

acceptance("Sidebar - Plugin API", function (needs) {
  needs.user({
    sidebar_sections: [
      {
        id: 111,
        title: "Community",
        links: [
          {
            id: 329,
            name: "Everything",
            value: "/latest",
            icon: "layer-group",
            external: false,
            segment: "primary",
          },
          {
            id: 330,
            name: "Users",
            value: "/u",
            icon: "users",
            external: false,
            segment: "secondary",
          },
          {
            id: 331,
            name: "Info",
            value: "/about",
            icon: "info-circle",
            external: false,
            segment: "secondary",
          },
          {
            id: 332,
            name: "Faq",
            value: "/faq",
            icon: "question-circle",
            external: false,
            segment: "secondary",
          },
          {
            id: 333,
            name: "My Posts",
            value: "/my/activity",
            icon: "user",
            external: false,
            segment: "primary",
          },
          {
            id: 334,
            name: "Review",
            value: "/review",
            icon: "flag",
            external: false,
            segment: "secondary",
          },
          {
            id: 335,
            name: "Admin",
            value: "/admin",
            icon: "wrench",
            external: false,
            segment: "primary",
          },
          {
            id: 336,
            name: "Groups",
            value: "/g",
            icon: "user-friends",
            external: false,
            segment: "secondary",
          },
          {
            id: 337,
            name: "Badges",
            value: "/badges",
            icon: "certificate",
            external: false,
            segment: "secondary",
          },
        ],
        slug: "community",
        public: true,
        system: true,
      },
    ],
  });

  needs.settings({
    navigation_menu: "sidebar",
  });

  needs.hooks.afterEach(() => {
    linkDidInsert = undefined;
    linkDestroy = undefined;
    sectionDestroy = undefined;
  });

  let linkDidInsert, linkDestroy, sectionDestroy;

  test("Multiple header actions and links", async function (assert) {
    withPluginApi("1.3.0", (api) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            get name() {
              return "test-chat-channels";
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

                  get classNames() {
                    return "my-class-name";
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
                    return "d-chat";
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
                  didInsert() {
                    linkDidInsert = "link test";
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
      linkDidInsert,
      "link test",
      "calls link didInsert function"
    );

    assert.strictEqual(
      query(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-text"
      ).textContent.trim(),
      "chat channels text",
      "displays header with correct text"
    );

    await click(
      ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-dropdown summary"
    );

    assert.strictEqual(
      queryAll(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-dropdown .select-kit-collection li"
      ).length,
      2,
      "displays two actions"
    );

    const actions = queryAll(
      ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-dropdown .select-kit-collection li"
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
      ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-link"
    );

    assert.strictEqual(
      links[0].textContent.trim(),
      "random channel text",
      "displays first link with correct text"
    );

    assert.ok(
      exists(".sidebar-section-link.my-class-name"),
      "sets the custom class name for the section link"
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
      links[0].children[0].style.color,
      "rgb(255, 0, 0)",
      "has correct prefix color"
    );

    assert.strictEqual(
      links[0].children[0].children[0].classList.contains("d-icon-d-chat"),
      true,
      "displays prefix icon"
    );

    assert.strictEqual(
      links[0].children[0].children[1].classList.contains("d-icon-lock"),
      true,
      "displays prefix icon badge"
    );

    assert.strictEqual(
      links[0].children[2].children[0].classList.contains("d-icon-circle"),
      true,
      "displays suffix icon"
    );

    assert.strictEqual(
      links[1].children[1].textContent.trim(),
      "dev channel text",
      "displays second link with correct text"
    );

    assert.strictEqual(
      links[1].title,
      "dev channel title",
      "displays second link with correct title attribute"
    );

    assert.strictEqual(
      links[1].children[0].style.color,
      "",
      "has no color style when value is invalid"
    );

    assert.strictEqual(
      links[1].children[0].textContent.trim(),
      "test text",
      "displays prefix text"
    );

    assert.strictEqual(
      links[2].children[1].textContent.trim(),
      "fun channel text",
      "displays third link with correct text"
    );

    assert.strictEqual(
      links[2].title,
      "fun channel title",
      "displays third link with correct title attribute"
    );

    assert.strictEqual(
      links[2].children[0].children[0].getAttribute("src"),
      "/test.png",
      "uses correct prefix image url"
    );

    assert.strictEqual(
      query(".sidebar-section-link-hover button").title,
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
    withPluginApi("1.3.0", (api) => {
      api.addSidebarSection((BaseCustomSidebarSection) => {
        return class extends BaseCustomSidebarSection {
          get name() {
            return "test-chat-channels";
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
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-header-text"
      ).textContent.trim(),
      "chat channels text",
      "displays header with correct text"
    );

    assert.ok(
      exists("button.sidebar-section-header-button"),
      "displays single header action button"
    );

    assert.ok(
      !exists(
        ".sidebar-section[data-section-name='test-chat-channels'] .sidebar-section-content a"
      ),
      "displays no links"
    );
  });

  test("API bridge for decorating hamburger-menu widget with footer links", async function (assert) {
    withPluginApi("1.3.0", (api) => {
      api.decorateWidget("hamburger-menu:footerLinks", () => {
        return {
          route: "discovery.top",
          rawLabel: "my top",
          className: "my-custom-top",
        };
      });
    });

    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    const myCustomTopSectionLink = query(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-content-main .sidebar-section-link[data-link-name='my-custom-top']"
    );

    assert.ok(
      myCustomTopSectionLink,
      "adds my custom top section link to community section under the secondary section in the More... links drawer"
    );

    assert.ok(
      myCustomTopSectionLink.href.endsWith("/top"),
      "sets the right href attribute for the my custom top section link"
    );

    assert.strictEqual(
      myCustomTopSectionLink.textContent.trim(),
      "my top",
      "displays the right text for my custom top section link"
    );
  });

  test("API bridge for decorating hamburger-menu widget with general links", async function (assert) {
    withPluginApi("1.3.0", (api) => {
      api.decorateWidget("hamburger-menu:generalLinks", () => {
        return {
          route: "discovery.latest",
          label: "filters.latest.title",
        };
      });

      api.decorateWidget("hamburger-menu:generalLinks", () => {
        return {
          route: "discovery.unread",
          rawLabel: "my unreads",
        };
      });

      api.decorateWidget("hamburger-menu:generalLinks", () => {
        return {
          route: "discovery.top",
          rawLabel: "my top",
          className: "my-custom-top",
        };
      });

      api.decorateWidget("hamburger-menu:generalLinks", () => {
        return {
          href: "/c/bug?status=open",
          rawLabel: "open bugs",
        };
      });

      api.decorateWidget("hamburger-menu:generalLinks", () => {
        return {
          href: "/t/internationalization-localization/280",
          rawLabel: "my favourite topic",
        };
      });
    });

    await visit("/");

    const customLatestSectionLink = query(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='latest']"
    );

    assert.ok(
      customLatestSectionLink,
      "adds custom latest section link to community section"
    );

    assert.ok(
      customLatestSectionLink.href.endsWith("/latest"),
      "sets the right href attribute for the custom latest section link"
    );

    assert.strictEqual(
      customLatestSectionLink.textContent.trim(),
      I18n.t("filters.latest.title"),
      "displays the right text for custom latest section link"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    const customUnreadSectionLink = query(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-unreads']"
    );

    assert.ok(
      customUnreadSectionLink,
      "adds custom unread section link to community section"
    );

    assert.ok(
      customUnreadSectionLink.href.endsWith("/unread"),
      "sets the right href attribute for the custom unread section link"
    );

    assert.strictEqual(
      customUnreadSectionLink.textContent.trim(),
      "my unreads",
      "displays the right text for custom unread section link"
    );

    const customTopSectionLInk = query(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-custom-top']"
    );

    assert.ok(
      customTopSectionLInk,
      "adds custom top section link to community section with right link class"
    );

    const openBugsSectionLink = query(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='open-bugs']"
    );

    assert.ok(
      openBugsSectionLink,
      "adds custom open bugs section link to community section with right link class"
    );

    assert.ok(
      openBugsSectionLink.href.endsWith("/c/bug?status=open"),
      "sets the right href attribute for the custom open bugs section link"
    );

    // close more links
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    await visit("/t/internationalization-localization/280");

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='my-favourite-topic'].active"
      ),
      "displays my favourite topic custom section link when current route matches the link's route"
    );

    await visit("/t/short-topic-with-two-posts/54077");

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link-my-favourite-topic.active"
      ),
      "does not display my favourite topic custom section link when current route does not match the link's route"
    );
  });

  test("Section that is not displayed via displaySection", async function (assert) {
    withPluginApi("1.3.0", (api) => {
      api.addSidebarSection((BaseCustomSidebarSection) => {
        return class extends BaseCustomSidebarSection {
          get name() {
            return "test-chat-channels";
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

          get displaySection() {
            return false;
          }
        };
      });
    });

    await visit("/");

    assert.notOk(
      exists(".sidebar-section[data-section-name='test-chat-channels']"),
      "does not display the section"
    );
  });

  test("Registering a custom countable for a section link in the user's sidebar categories section", async function (assert) {
    try {
      return await withPluginApi("1.6.0", async (api) => {
        const categories = Site.current().categories;
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
          badgeTextFunction: (count) => {
            return `some custom ${count}`;
          },
          route: "discovery.latestCategory",
          routeQuery: { status: "open" },
          shouldRegister: ({ category }) => {
            if (category.name === category1.name) {
              return true;
            } else if (category.name === category2.name) {
              return false;
            }
          },
          refreshCountFunction: ({ category }) => {
            return category.topic_count;
          },
          prioritizeOverDefaults: ({ category }) => {
            return category.topic_count > 1000;
          },
        });

        await visit("/");

        assert.ok(
          exists(
            `.sidebar-section-link[data-category-id="${category1.id}"] .sidebar-section-link-suffix.unread`
          ),
          "the right suffix is displayed when custom countable is active"
        );

        assert.strictEqual(
          query(`.sidebar-section-link[data-category-id="${category1.id}"]`)
            .pathname,
          `/c/${category1.name}/${category1.id}`,
          "does not use route configured for custom countable when user has elected not to show any counts in sidebar"
        );

        assert.notOk(
          exists(
            `.sidebar-section-link[data-category-id="${category2.id}"] .sidebar-section-link-suffix.unread`
          ),
          "does not display suffix when custom countable is not registered"
        );

        updateCurrentUser({
          sidebar_list_destination: UNREAD_LIST_DESTINATION,
        });

        assert.strictEqual(
          query(
            `.sidebar-section-link[data-category-id="${category1.id}"] .sidebar-section-link-content-badge`
          ).innerText.trim(),
          I18n.t("sidebar.unread_count", { count: 1 }),
          "displays the right badge text in section link when unread is present and custom countable is not prioritised over unread"
        );

        category1.set("topic_count", 2000);

        api.refreshUserSidebarCategoriesSectionCounts();

        await settled();

        assert.strictEqual(
          query(
            `.sidebar-section-link[data-category-id="${category1.id}"] .sidebar-section-link-content-badge`
          ).innerText.trim(),
          `some custom ${category1.topic_count}`,
          "displays the right badge text in section link when unread is present but custom countable is prioritised over unread"
        );

        assert.strictEqual(
          query(`.sidebar-section-link[data-category-id="${category1.id}"]`)
            .pathname,
          `/c/${category1.name}/${category1.id}/l/latest`,
          "has the right pathname for section link"
        );

        assert.strictEqual(
          query(`.sidebar-section-link[data-category-id="${category1.id}"]`)
            .search,
          "?status=open",
          "has the right query params for section link"
        );
      });
    } finally {
      resetCustomCountables();
    }
  });
});
