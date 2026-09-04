import { getOwner } from "@ember/owner";
import { click, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatChannelListFilterMenu from "discourse/plugins/chat/discourse/components/chat-channel-list-filter-menu";
import ChatChannelListOptionsMenu from "discourse/plugins/chat/discourse/components/chat-channel-list-options-menu";
import ChatChannelListSortMenu from "discourse/plugins/chat/discourse/components/chat-channel-list-sort-menu";
import ChatSidebarChannelsFilterEmptyState from "discourse/plugins/chat/discourse/components/chat-sidebar-channels-filter-empty-state";

module(
  "Integration | Component | ChatChannelListOptionsMenu",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    test("shows browse and the current filter and sort", async function (assert) {
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      preferences.filter = "unread";
      preferences.sort = "priority";

      await render(
        <template>
          <ChatChannelListOptionsMenu />
          <DMenus />
        </template>
      );

      assert
        .dom('[data-menu-option-id="browseChannels"]')
        .hasText("Browse channels", "the browse action is shown");
      assert
        .dom('[data-menu-option-id="filterChannels"]')
        .hasAttribute("aria-expanded", "false", "the filter submenu is closed")
        .hasAttribute("aria-haspopup", "menu", "the filter exposes its submenu")
        .hasAttribute("aria-label", "Filter: Unreads")
        .hasText("Unreads", "the current filter is shown");
      assert
        .dom('[data-menu-option-id="sortChannels"]')
        .hasAttribute("aria-expanded", "false", "the sort submenu is closed")
        .hasAttribute("aria-haspopup", "menu", "the sort exposes its submenu")
        .hasAttribute("aria-label", "Sort: Priority")
        .hasText("Priority", "the current sort is shown");
    });

    test("opens the filter submenu", async function (assert) {
      await render(
        <template>
          <ChatChannelListOptionsMenu />
          <DMenus />
        </template>
      );

      await click('[data-menu-option-id="filterChannels"]');

      assert
        .dom('[data-menu-option-id="filterChannels"]')
        .hasAttribute(
          "aria-expanded",
          "true",
          "the trigger reports its submenu"
        );
      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-filter-menu"]')
        .hasAttribute("role", "menu", "the filter submenu has menu semantics");
      assert
        .dom(".chat-channel-list-filter-menu__all")
        .hasAttribute("aria-checked", "true", "the default filter is selected");
    });

    test("opens the sort submenu", async function (assert) {
      await render(
        <template>
          <ChatChannelListOptionsMenu />
          <DMenus />
        </template>
      );

      await click('[data-menu-option-id="sortChannels"]');

      assert
        .dom('[data-menu-option-id="sortChannels"]')
        .hasAttribute(
          "aria-expanded",
          "true",
          "the trigger reports its submenu"
        );
      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-sort-menu"]')
        .hasAttribute("role", "menu", "the sort submenu has menu semantics");
      assert
        .dom(".chat-channel-list-sort-menu__alphabetical")
        .hasAttribute("aria-checked", "true", "the default sort is selected");
    });

    test("switches between submenus without closing the parent", async function (assert) {
      await render(
        <template>
          <button class="menu-trigger" type="button">Open</button>
          <DMenus />
        </template>
      );
      const menu = getOwner(this).lookup("service:menu");
      await menu.show(find(".menu-trigger"), {
        component: ChatChannelListOptionsMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
      });

      await click('[data-menu-option-id="filterChannels"]');
      await click('[data-menu-option-id="sortChannels"]');

      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-options-menu"]')
        .exists("the parent menu remains open");
      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-filter-menu"]')
        .doesNotExist("the previous submenu closes");
      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-sort-menu"]')
        .exists("the selected submenu opens");
    });

    test("closes both menus before saving a selection", async function (assert) {
      let resolveSave;
      const savePromise = new Promise((resolve) => {
        resolveSave = resolve;
      });
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      const setSort = sinon.stub(preferences, "setSort").returns(savePromise);

      await render(
        <template>
          <button class="menu-trigger" type="button">Open</button>
          <DMenus />
        </template>
      );
      const menu = getOwner(this).lookup("service:menu");
      await menu.show(find(".menu-trigger"), {
        component: ChatChannelListOptionsMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
      });
      await click('[data-menu-option-id="sortChannels"]');

      await click(".chat-channel-list-sort-menu__priority");

      assert.true(setSort.calledOnce, "the selection starts saving");
      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-options-menu"]')
        .doesNotExist("the parent menu closes while the save is pending");
      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-sort-menu"]')
        .doesNotExist("the submenu closes while the save is pending");
      assert
        .dom(".menu-trigger")
        .isNotFocused("a pointer selection does not leave the cog visible");

      resolveSave(true);
      await settled();
    });

    test("does not focus the background trigger for a mobile modal", async function (assert) {
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      sinon.stub(preferences, "setFilter").resolves(true);

      await render(
        <template>
          <button class="menu-trigger" type="button">Open</button>
          <DMenus />
        </template>
      );
      const menu = getOwner(this).lookup("service:menu");
      sinon.stub(menu, "shouldRenderInModal").returns(true);
      await menu.show(find(".menu-trigger"), {
        component: ChatChannelListOptionsMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
      });
      await click('[data-menu-option-id="filterChannels"]');

      await click(".chat-channel-list-filter-menu__mentions");

      assert
        .dom(".menu-trigger")
        .isNotFocused("focus is not moved behind the mobile modal");
    });

    test("closes the submenu before browsing channels", async function (assert) {
      await render(
        <template>
          <button class="menu-trigger" type="button">Open</button>
          <DMenus />
        </template>
      );
      const menu = getOwner(this).lookup("service:menu");
      const router = getOwner(this).lookup("service:router");
      router.transitionTo = sinon.spy();
      await menu.show(find(".menu-trigger"), {
        component: ChatChannelListOptionsMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
      });
      await click('[data-menu-option-id="sortChannels"]');

      await click('[data-menu-option-id="browseChannels"]');

      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-options-menu"]')
        .doesNotExist("the parent menu closes");
      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-sort-menu"]')
        .doesNotExist("the submenu closes");
      assert.true(
        router.transitionTo.calledWith("chat.browse.open"),
        "the browse page opens"
      );
    });
  }
);

module("Integration | Component | ChatChannelListFilterMenu", function (hooks) {
  setupRenderingTest(hooks);

  test("shows and changes the selected filter", async function (assert) {
    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );
    preferences.filter = "unread";
    const setFilter = sinon.stub(preferences, "setFilter").resolves(true);

    await render(<template><ChatChannelListFilterMenu /></template>);

    assert
      .dom(".chat-channel-list-filter-menu__unread")
      .hasAttribute(
        "role",
        "menuitemradio",
        "filter choices have radio semantics"
      )
      .hasAttribute("aria-checked", "true", "the current filter is selected");

    await click(".chat-channel-list-filter-menu__mentions");

    assert.true(
      setFilter.calledWith("mentions"),
      "the selected filter is saved"
    );
  });

  test("marks only the active filter as selected", async function (assert) {
    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );
    preferences.filter = "active";

    await render(<template><ChatChannelListFilterMenu /></template>);

    assert
      .dom(".chat-channel-list-filter-menu__active")
      .hasAttribute("aria-checked", "true", "active is selected")
      .includesText("Active only")
      .includesText("New activity in last 30 days");
    assert
      .dom(".chat-channel-list-filter-menu__active .d-icon")
      .exists("the selected option has a checkmark");
    assert
      .dom(".chat-channel-list-filter-menu__all")
      .hasAttribute("aria-checked", "false", "all is not selected");
    assert
      .dom(".chat-channel-list-filter-menu__all .d-icon")
      .exists("unselected options retain a checkmark gutter");
    assert
      .dom('.chat-channel-list-filter-menu [aria-checked="true"]')
      .exists({ count: 1 }, "only one filter is selected");
  });
});

module("Integration | Component | ChatChannelListSortMenu", function (hooks) {
  setupRenderingTest(hooks);

  test("shows and changes the selected sort", async function (assert) {
    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );
    preferences.sort = "priority";
    const setSort = sinon.stub(preferences, "setSort").resolves(true);

    await render(<template><ChatChannelListSortMenu /></template>);

    assert
      .dom(".chat-channel-list-sort-menu__priority")
      .hasAttribute(
        "role",
        "menuitemradio",
        "sort choices have radio semantics"
      )
      .hasAttribute("aria-checked", "true", "the current sort is selected")
      .includesText("Priority")
      .includesText("Mentions, then unreads, then recent activity");

    await click(".chat-channel-list-sort-menu__recent-activity");

    assert.true(
      setSort.calledWith("recent_activity"),
      "the selected sort is saved"
    );
  });
});

module(
  "Integration | Component | ChatSidebarChannelsFilterEmptyState",
  function (hooks) {
    setupRenderingTest(hooks);

    test("does not compete with the sidebar text-search empty state", async function (assert) {
      const sidebarState = getOwner(this).lookup("service:sidebar-state");
      sidebarState.filter = "missing";

      await render(
        <template>
          <ul>
            <ChatSidebarChannelsFilterEmptyState />
          </ul>
        </template>
      );

      assert
        .dom(".chat-sidebar-channels-filter-empty-state")
        .doesNotExist("the channel-filter reset is hidden during text search");
    });

    test("resets the channel filter", async function (assert) {
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      const setFilter = sinon.stub(preferences, "setFilter").resolves(true);

      await render(
        <template>
          <ul>
            <ChatSidebarChannelsFilterEmptyState />
          </ul>
        </template>
      );

      assert
        .dom(".chat-sidebar-channels-filter-empty-state")
        .hasTagName("li", "the state is valid section-list content")
        .includesText(
          "No channels match this filter.",
          "the empty state explains the filter"
        );

      await click(".chat-sidebar-channels-filter-empty-state__reset");

      assert.true(setFilter.calledWith("all"), "the filter is reset");
    });
  }
);
