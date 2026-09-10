import { getOwner } from "@ember/owner";
import {
  click,
  find,
  focus,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ModalContainer from "discourse/components/modal-container";
import DMenus from "discourse/float-kit/components/d-menus";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatChannelListFilterMenu from "discourse/plugins/chat/discourse/components/chat-channel-list-filter-menu";
import ChatChannelListOptionsButton from "discourse/plugins/chat/discourse/components/chat-channel-list-options-button";
import ChatChannelListSidebarMenu from "discourse/plugins/chat/discourse/components/chat-channel-list-sidebar-menu";
import ChatChannelListSortMenu from "discourse/plugins/chat/discourse/components/chat-channel-list-sort-menu";
import ChatSidebarChannelListFilterEmptyState from "discourse/plugins/chat/discourse/components/chat-sidebar-channel-list-filter-empty-state";
import { CHANNEL_LIST_SECTION_OPTIONS } from "discourse/plugins/chat/discourse/lib/chat-channel-list-options";

const sectionData = (section) => ({
  section,
  ...CHANNEL_LIST_SECTION_OPTIONS[section],
});

const CHANNELS_DATA = sectionData("channels");
const STARRED_DATA = sectionData("starred");
const DMS_DATA = sectionData("dms");

module(
  "Integration | Component | ChatChannelListSidebarMenu",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    test("shows browse and the current filter and sort", async function (assert) {
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      preferences.channelsFilter = "unread";
      preferences.channelsSort = "priority";

      await render(
        <template>
          <ChatChannelListSidebarMenu @data={{CHANNELS_DATA}} />
          <DMenus />
        </template>
      );

      assert
        .dom('[data-menu-option-id="browseChannels"]')
        .hasText(
          i18n("chat.channels_list_popup.browse"),
          "the browse action is shown"
        );
      assert
        .dom('[data-menu-option-id="filterChannels"]')
        .hasAttribute("aria-expanded", "false", "the filter submenu is closed")
        .hasAttribute("aria-haspopup", "menu", "the filter exposes its submenu")
        .hasAttribute(
          "aria-label",
          i18n("chat.channel_list.options.current_filter", {
            filter: i18n("chat.channel_list.filter.unread"),
          })
        )
        .hasText(
          i18n("chat.channel_list.filter.unread"),
          "the current filter is shown"
        );
      assert
        .dom('[data-menu-option-id="sortChannels"]')
        .hasAttribute("aria-expanded", "false", "the sort submenu is closed")
        .hasAttribute("aria-haspopup", "menu", "the sort exposes its submenu")
        .hasAttribute(
          "aria-label",
          i18n("chat.channel_list.options.current_sort", {
            sort: i18n("chat.channel_list.sort.priority"),
          })
        )
        .hasText(
          i18n("chat.channel_list.sort.priority"),
          "the current sort is shown"
        );
    });

    test("opens the filter submenu", async function (assert) {
      await render(
        <template>
          <ChatChannelListSidebarMenu @data={{CHANNELS_DATA}} />
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
          <ChatChannelListSidebarMenu @data={{CHANNELS_DATA}} />
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

    test("shows the filter, sort, and no top-level actions for the starred header", async function (assert) {
      await render(
        <template>
          <ChatChannelListSidebarMenu @data={{STARRED_DATA}} />
          <DMenus />
        </template>
      );

      assert
        .dom('[data-menu-option-id="browseChannels"]')
        .doesNotExist("the browse option is hidden");
      assert
        .dom('[data-menu-option-id="startDm"]')
        .doesNotExist("the new message action is hidden");
      assert
        .dom('[data-menu-option-id="filterChannels"]')
        .exists("the filter option is shown");
      assert
        .dom('[data-menu-option-id="sortChannels"]')
        .exists("the sort option is shown behind a fly-out submenu");
    });

    test("shows the new message, group chat, filter, and sort options for the direct messages header", async function (assert) {
      this.siteSettings.chat_max_direct_message_users = 20;
      sinon
        .stub(getOwner(this).lookup("service:chat"), "userCanDirectMessage")
        .value(true);
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      preferences.dmsSort = "recent_activity";

      await render(
        <template>
          <ChatChannelListSidebarMenu @data={{DMS_DATA}} />
          <DMenus />
        </template>
      );

      assert
        .dom('[data-menu-option-id="startDm"]')
        .hasText(
          i18n("chat.direct_messages.new"),
          "the new message action is shown"
        );
      assert
        .dom('[data-menu-option-id="startGroupChat"]')
        .hasText(
          i18n("chat.direct_messages.new_group"),
          "the new group chat action is shown"
        );
      assert
        .dom('[data-menu-option-id="browseChannels"]')
        .doesNotExist("the browse option is hidden");
      assert
        .dom('[data-menu-option-id="filterChannels"]')
        .exists("the filter option is shown");
      assert
        .dom('[data-menu-option-id="sortChannels"]')
        .exists("the sort option is shown behind a fly-out submenu");

      await click('[data-menu-option-id="sortChannels"]');

      assert
        .dom(".chat-channel-list-sort-menu__recent-activity")
        .hasAttribute(
          "aria-checked",
          "true",
          "the current sort choice is selected"
        );
      assert
        .dom('.chat-channel-list-options-menu [aria-checked="true"]')
        .exists({ count: 1 }, "exactly one sort choice is checked");
    });

    for (const [option, mode] of [
      ["startDm", "search"],
      ["startGroupChat", "new-group"],
    ]) {
      test(`opens ${mode} from the direct messages header menu`, async function (assert) {
        this.siteSettings.chat_max_direct_message_users = 20;
        sinon
          .stub(getOwner(this).lookup("service:chat"), "userCanDirectMessage")
          .value(true);

        await render(
          <template>
            <button class="menu-trigger" type="button">Open</button>
            <DMenus />
            <ModalContainer />
          </template>
        );
        const menu = getOwner(this).lookup("service:menu");
        await menu.show(find(".menu-trigger"), {
          component: ChatChannelListSidebarMenu,
          contentRole: "menu",
          identifier: "chat-channel-list-options-menu",
          data: DMS_DATA,
        });

        await click(`[data-menu-option-id="${option}"]`);

        assert
          .dom(".chat-modal-new-message")
          .exists("the new message modal opens");
        assert
          .dom(`.chat-message-creator__${mode}`)
          .exists("the requested mode is shown immediately");
        assert
          .dom('.fk-d-menu[data-identifier="chat-channel-list-options-menu"]')
          .doesNotExist("the menu closes");
        if (mode === "new-group") {
          await click(".chat-message-creator__add-members__close-btn");

          assert
            .dom(".chat-message-creator__search")
            .exists("canceling group creation returns to search");
        }
      });
    }

    test("hides the new message option when the user cannot send direct messages", async function (assert) {
      await render(
        <template>
          <ChatChannelListSidebarMenu @data={{DMS_DATA}} />
          <DMenus />
        </template>
      );

      assert
        .dom('[data-menu-option-id="startDm"]')
        .doesNotExist("the new message action is hidden without permission");
      assert
        .dom('[data-menu-option-id="startGroupChat"]')
        .doesNotExist("the group chat action is hidden without permission");
      assert
        .dom(".dropdown-menu__divider")
        .doesNotExist(
          "the top-level divider is dropped with no actions above it"
        );
      assert
        .dom('[data-menu-option-id="filterChannels"]')
        .exists("the filter option is still shown");
    });

    test("hides group chat when only one recipient is allowed", async function (assert) {
      this.siteSettings.chat_max_direct_message_users = 1;
      sinon
        .stub(getOwner(this).lookup("service:chat"), "userCanDirectMessage")
        .value(true);

      await render(
        <template><ChatChannelListSidebarMenu @data={{DMS_DATA}} /></template>
      );

      assert
        .dom('[data-menu-option-id="startDm"]')
        .exists("direct messages are available");
      assert
        .dom('[data-menu-option-id="startGroupChat"]')
        .doesNotExist("group chat is unavailable");
    });

    test("hides the create channel option for non-staff", async function (assert) {
      await render(
        <template>
          <ChatChannelListSidebarMenu @data={{CHANNELS_DATA}} />
          <DMenus />
        </template>
      );

      assert
        .dom('[data-menu-option-id="createChannel"]')
        .doesNotExist("create channel is hidden for non-staff");
    });

    test("creates a channel from the channels header menu", async function (assert) {
      getOwner(this).lookup("service:current-user").set("admin", true);

      await render(
        <template>
          <button class="menu-trigger" type="button">Open</button>
          <DMenus />
          <ModalContainer />
        </template>
      );
      const menu = getOwner(this).lookup("service:menu");
      await menu.show(find(".menu-trigger"), {
        component: ChatChannelListSidebarMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
        data: CHANNELS_DATA,
      });

      assert
        .dom('[data-menu-option-id="createChannel"]')
        .hasText(
          i18n("chat.channels_list_popup.create"),
          "the create channel action is shown for staff"
        );

      await click('[data-menu-option-id="createChannel"]');

      assert
        .dom(".chat-modal-create-channel")
        .exists("the create channel modal opens");
      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-options-menu"]')
        .doesNotExist("the menu closes");
    });

    test("selecting a sort choice from the sort fly-out saves it", async function (assert) {
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      const setSort = sinon.stub(preferences, "setSort").resolves(true);

      await render(
        <template>
          <button class="menu-trigger" type="button">Open</button>
          <DMenus />
        </template>
      );
      const menu = getOwner(this).lookup("service:menu");
      await menu.show(find(".menu-trigger"), {
        component: ChatChannelListSidebarMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
        data: STARRED_DATA,
      });

      await click('[data-menu-option-id="sortChannels"]');
      await click(".chat-channel-list-sort-menu__priority");

      assert.true(
        setSort.calledWith("starred", "priority"),
        "the selected sort is saved for the starred section"
      );
      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-options-menu"]')
        .doesNotExist("the header menu closes after selection");
      assert
        .dom(".menu-trigger")
        .isFocused("focus returns to the trigger after selection");
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
        component: ChatChannelListSidebarMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
        data: CHANNELS_DATA,
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
        component: ChatChannelListSidebarMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
        data: CHANNELS_DATA,
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
        .isFocused("the menu restores focus to its trigger after selection");

      resolveSave(true);
      await settled();
    });

    test("closes mobile modals and restores focus after selection", async function (assert) {
      forceMobile();
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      sinon.stub(preferences, "setFilter").resolves(true);

      await render(
        <template>
          <button class="menu-trigger" type="button">Open</button>
          <DMenus />
          <ModalContainer />
        </template>
      );
      const menu = getOwner(this).lookup("service:menu");
      await menu.show(find(".menu-trigger"), {
        component: ChatChannelListSidebarMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
        modalForMobile: true,
        data: CHANNELS_DATA,
      });
      await click('[data-menu-option-id="filterChannels"]');

      assert
        .dom(
          '.fk-d-menu-modal[data-identifier="chat-channel-list-filter-menu"]'
        )
        .exists("the submenu renders as a mobile modal");
      await click(".chat-channel-list-filter-menu__mentions");
      assert.dom(".fk-d-menu-modal").doesNotExist("both modal menus close");

      assert
        .dom(".menu-trigger")
        .isFocused("focus returns to the trigger after the modals close");
    });

    test("Escape and keyboard selection close the menu tree", async function (assert) {
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      const setFilter = sinon.stub(preferences, "setFilter").resolves(true);
      await render(
        <template>
          <button class="menu-trigger" type="button">Open</button>
          <DMenus />
        </template>
      );
      const menu = getOwner(this).lookup("service:menu");
      await menu.show(find(".menu-trigger"), {
        component: ChatChannelListSidebarMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
        data: CHANNELS_DATA,
      });
      await click('[data-menu-option-id="filterChannels"]');
      await focus(".chat-channel-list-filter-menu__mentions");
      await triggerKeyEvent(document.activeElement, "keydown", "Escape");

      assert
        .dom(".chat-channel-list-filter-menu")
        .doesNotExist("Escape dismisses the submenu");
      assert
        .dom(".chat-channel-list-options-menu")
        .doesNotExist("Escape dismisses the parent menu too");
      assert
        .dom(".menu-trigger")
        .isFocused("focus returns to the outer trigger");

      await menu.show(find(".menu-trigger"), {
        component: ChatChannelListSidebarMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
        data: CHANNELS_DATA,
      });
      await focus('[data-menu-option-id="filterChannels"]');
      // Key events from test helpers do not synthesize the native button click.
      await triggerEvent(document.activeElement, "click", { detail: 0 });
      await focus(".chat-channel-list-filter-menu__mentions");
      await triggerKeyEvent(document.activeElement, "keydown", "Enter");

      assert.true(
        setFilter.calledWith("channels", "mentions"),
        "keyboard selection saves the filter"
      );
      assert
        .dom(".chat-channel-list-options-menu")
        .doesNotExist("selection closes the parent");
      assert
        .dom(".chat-channel-list-filter-menu")
        .doesNotExist("selection closes the submenu");
      assert
        .dom(".menu-trigger")
        .isFocused("focus returns to the sidebar trigger");
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
        component: ChatChannelListSidebarMenu,
        contentRole: "menu",
        identifier: "chat-channel-list-options-menu",
        data: CHANNELS_DATA,
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
    preferences.channelsFilter = "unread";
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
      setFilter.calledWith("channels", "mentions"),
      "the selected filter is saved for the channels section"
    );
  });

  test("marks only the active filter as selected", async function (assert) {
    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );
    preferences.channelsFilter = "active";

    await render(<template><ChatChannelListFilterMenu /></template>);

    assert
      .dom(".chat-channel-list-filter-menu__active")
      .hasAttribute("aria-checked", "true", "active is selected")
      .includesText(i18n("chat.channel_list.filter.active"))
      .includesText(
        i18n("chat.channel_list.filter.active_description", { days: 30 })
      );
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
    preferences.channelsSort = "priority";
    const setSort = sinon.stub(preferences, "setSort").resolves(true);

    await render(
      <template><ChatChannelListSortMenu @section="channels" /></template>
    );

    assert
      .dom(".chat-channel-list-sort-menu__priority")
      .hasAttribute(
        "role",
        "menuitemradio",
        "sort choices have radio semantics"
      )
      .hasAttribute("aria-checked", "true", "the current sort is selected")
      .includesText(i18n("chat.channel_list.sort.priority"))
      .includesText(i18n("chat.channel_list.sort.priority_description"));

    await click(".chat-channel-list-sort-menu__recent-activity");

    assert.true(
      setSort.calledWith("channels", "recent_activity"),
      "the selected sort is saved"
    );
  });
});

module(
  "Integration | Component | ChatSidebarChannelListFilterEmptyState",
  function (hooks) {
    setupRenderingTest(hooks);

    test("does not compete with the sidebar text-search empty state", async function (assert) {
      const sidebarState = getOwner(this).lookup("service:sidebar-state");
      sidebarState.filter = "missing";

      await render(
        <template>
          <ul>
            <ChatSidebarChannelListFilterEmptyState />
          </ul>
        </template>
      );

      assert
        .dom(".chat-sidebar-channels-filter-empty-state")
        .doesNotExist("the channel-filter reset is hidden during text search");
    });

    test("resets the channels filter by default", async function (assert) {
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      const setFilter = sinon.stub(preferences, "setFilter").resolves(true);

      await render(
        <template>
          <ul>
            <ChatSidebarChannelListFilterEmptyState />
          </ul>
        </template>
      );

      assert
        .dom(".chat-sidebar-channels-filter-empty-state")
        .hasTagName("li", "the state is valid section-list content")
        .includesText(
          i18n("chat.channel_list.empty.filtered"),
          "the empty state explains the filter"
        );

      await click(".chat-sidebar-channels-filter-empty-state__reset");

      assert.true(
        setFilter.calledWith("channels", "all"),
        "the channels filter is reset"
      );
    });

    test("resets the filter of the section it is rendered for", async function (assert) {
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      const setFilter = sinon.stub(preferences, "setFilter").resolves(true);

      await render(
        <template>
          <ul>
            <ChatSidebarChannelListFilterEmptyState @section="starred" />
            <ChatSidebarChannelListFilterEmptyState @section="dms" />
          </ul>
        </template>
      );

      await click(".chat-sidebar-channels-filter-empty-state__reset");

      assert.true(
        setFilter.calledWith("starred", "all"),
        "the starred filter is reset"
      );

      const resets = document.querySelectorAll(
        ".chat-sidebar-channels-filter-empty-state__reset"
      );
      await click(resets[1]);

      assert.true(
        setFilter.calledWith("dms", "all"),
        "the dms filter is reset"
      );
    });

    test("renders an illustrated state matching the no-channels layout", async function (assert) {
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      const setFilter = sinon.stub(preferences, "setFilter").resolves(true);

      await render(
        <template>
          <ChatSidebarChannelListFilterEmptyState
            @layout="empty-state"
            @section="dms"
          />
        </template>
      );

      assert
        .dom(".empty-state__image")
        .exists("the same illustration as the no-channels state is shown");
      assert
        .dom(".empty-state__title")
        .hasText(
          i18n("chat.channel_list.empty.filtered"),
          "the title explains the filter"
        );

      await click(".empty-state__cta .btn");

      assert.true(
        setFilter.calledWith("dms", "all"),
        "the show all action resets the dms filter"
      );
    });
  }
);

module(
  "Integration | Component | ChatChannelListOptionsButton",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    test("opens the shared channel list menu for its section", async function (assert) {
      sinon
        .stub(getOwner(this).lookup("service:chat"), "userCanDirectMessage")
        .value(true);

      await render(
        <template>
          <ChatChannelListOptionsButton @section="dms" />
          <DMenus />
        </template>
      );

      await click(".chat-channel-list-options-button");

      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-options-menu"]')
        .hasAttribute("role", "menu", "the shared channel list menu opens");
      assert
        .dom('[data-menu-option-id="startDm"]')
        .exists("the new message action is exposed");
      assert
        .dom('[data-menu-option-id="filterChannels"]')
        .exists("the filter action is exposed");
      assert
        .dom('[data-menu-option-id="sortChannels"]')
        .exists("the sort action is exposed");
    });

    test("saves a sort from the shared menu for the trigger's section", async function (assert) {
      const preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      const setSort = sinon.stub(preferences, "setSort").resolves(true);

      await render(
        <template>
          <ChatChannelListOptionsButton @section="dms" />
          <DMenus />
        </template>
      );

      await click(".chat-channel-list-options-button");
      await click('[data-menu-option-id="sortChannels"]');
      await click(".chat-channel-list-sort-menu__recent-activity");

      assert.true(
        setSort.calledWith("dms", "recent_activity"),
        "the selected sort is saved for the section"
      );
      assert
        .dom('.fk-d-menu[data-identifier="chat-channel-list-options-menu"]')
        .doesNotExist("the menu closes after selection");
    });
  }
);
