import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { apiInitializer } from "discourse/lib/api";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import ChannelHeader from "../components/channel-header.gjs";
import DmHeader from "../components/dm-header.gjs";
import MemberList from "../components/member-list.gjs";
import CreateChannelModal from "../components/modal/create-channel.gjs";
import ServerHeader from "../components/server-header.gjs";
import TopicLayout from "../components/topic-layout.gjs";
import UserPanel from "../components/user-panel.gjs";
import AiConversations from "../lib/ai-conversations.js";
import ChannelActions from "../lib/channel-actions.js";
import ChannelCreator from "../lib/channel-creator.js";
import ChannelDirectory from "../lib/channel-directory.js";
import ChannelPrivacy from "../lib/channel-privacy.js";
import {
  CHANNELS_PANEL,
  DMS_PANEL,
  DMS_SECTION,
  SECTION_PREFIX,
  TOP_SECTION,
} from "../lib/constants.js";
import CurrentChannel from "../lib/current-channel.js";
import DirectMessages from "../lib/direct-messages.js";
import LastChannel from "../lib/last-channel.js";
import installLongPress from "../lib/long-press.js";
import MemberListData from "../lib/member-list.js";
import OpenChannels from "../lib/open-channels.js";
import relabelBackLink from "../lib/relabel-back-link.js";
import replaySlideIn from "../lib/replay-slide-in.js";
import scrollToActive from "../lib/scroll-to-active.js";
import SidebarSections from "../lib/sidebar-sections.js";

export default apiInitializer((api) => {
  const owner = getOwnerWithFallback(api);
  // The theme is built around the sidebar, so it doesn't follow the site's
  // navigation menu setting. Only the client reads that setting.
  owner.lookup("service:site-settings").navigation_menu = "sidebar";
  relabelBackLink();
  const sidebarSections = new SidebarSections(api.getCurrentUser());
  const creator = new ChannelCreator(owner);
  const channelActions = new ChannelActions(
    owner,
    sidebarSections,
    new ChannelPrivacy(owner, creator),
    creator
  );
  const directory = new ChannelDirectory(
    owner,
    sidebarSections,
    channelActions
  );
  const modal = owner.lookup("service:modal");
  const currentChannel = new CurrentChannel(owner);
  // Who's online comes from chat's presence, which only signed-in people can
  // see, so visitors get no member list rather than everyone offline.
  const memberList =
    api.getCurrentUser() && new MemberListData(owner, currentChannel);
  const directMessages = new DirectMessages(
    owner,
    currentChannel,
    channelActions
  );
  const aiConversations = new AiConversations(owner, directMessages);

  if (
    settings.include_chat_channels &&
    owner.lookup("service:chat")?.userCanChat
  ) {
    new OpenChannels(owner).install();
  }
  const sidebarState = owner.lookup("service:sidebar-state");

  const openCreateChannel = (sectionIndex = null) =>
    modal.show(CreateChannelModal, {
      model: { creator, sidebarSections, sectionIndex },
    });

  const createAction = (sectionIndex) => {
    if (!creator.types.length) {
      return;
    }

    return [
      {
        id: "createChannel",
        icon: "plus",
        title: i18n(themePrefix("create_channel.action")),
        action: () => openCreateChannel(sectionIndex),
      },
    ];
  };

  // Channels in no section sit at the top with no heading. A
  // section without a header never collapses.
  class TopSection extends BaseCustomSidebarSection {
    name = TOP_SECTION;
    text = "";
    hideSectionHeader = true;

    get links() {
      return directory.layout.top;
    }

    get displaySection() {
      return this.links.length > 0;
    }
  }

  const headedSection = (index, name) =>
    class extends BaseCustomSidebarSection {
      name = name;
      actionsInline = true;

      get text() {
        return sidebarSections.sections[index]?.name;
      }

      get links() {
        return directory.layout.sections[index]?.links || [];
      }

      get actions() {
        return [
          ...(createAction(index) || []),
          channelActions.sectionAction(index),
        ].filter(Boolean);
      }
    };

  api.addSidebarPanel(
    (BaseCustomSidebarPanel) =>
      class extends BaseCustomSidebarPanel {
        key = CHANNELS_PANEL;
        hidden = true;
        expandActiveSection = true;
        scrollActiveLinkIntoView = true;
      }
  );

  // A sidebar section per section. Named after it, since that's what keeps a
  // section collapsed across page loads, with the position added where two
  // share a name. Rebuilt whenever the sections change.
  const panel = sidebarState.panels.find((p) => p.key === CHANNELS_PANEL);
  const syncSections = () => {
    const seen = new Set();

    panel.sections = [
      TopSection,
      ...sidebarSections.sections.map((section, index) => {
        let name = `${SECTION_PREFIX}${section.name
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, "-")}`;
        if (seen.has(name)) {
          name = `${name}-${index}`;
        }
        seen.add(name);
        return headedSection(index, name);
      }),
    ];
  };

  syncSections();
  sidebarSections.onChange = syncSections;

  // Registered even before the user can DM, since a first DM from someone
  // else makes the list available without a page load.
  if (directMessages.supported) {
    api.addSidebarPanel(
      (BaseCustomSidebarPanel) =>
        class extends BaseCustomSidebarPanel {
          key = DMS_PANEL;
          hidden = true;
          scrollActiveLinkIntoView = true;
        }
    );

    api.addSidebarSection(
      (BaseSection) =>
        class extends BaseSection {
          name = DMS_SECTION;
          text = "";
          hideSectionHeader = true;

          get links() {
            return directMessages.links;
          }
        },
      DMS_PANEL
    );
  }

  // Rendered afresh each time the slide-in list opens. Core scrolls the
  // current channel's row into view (the panels ask it to), but then focuses
  // the slide-in's first link, which scrolls it back to the top; so scroll
  // again a frame later, still before the list is first drawn.
  const onListInserted = (element) => {
    const list = element.closest(".sidebar-hamburger-dropdown");
    if (list) {
      requestAnimationFrame(() => scrollToActive(list));
    }
    replaySlideIn(element);
  };

  api.renderInOutlet(
    "before-sidebar-sections",
    <template>
      <ServerHeader
        @aiConversations={{aiConversations}}
        @canCreate={{creator.types.length}}
        @directMessages={{directMessages}}
        @onCreate={{openCreateChannel}}
      />
      <DmHeader @directMessages={{directMessages}} />
      <span hidden {{didInsert onListInserted}}></span>
    </template>
  );

  // On wide screens core's header contents are hidden and this row takes
  // their place, so the header keeps its height and the layout built on it.
  api.renderInOutlet(
    "after-header",
    <template>
      {{#unless currentChannel.isAuthPage}}
        <ChannelHeader
          @aiConversations={{aiConversations}}
          @canCreate={{creator.types.length}}
          @currentChannel={{currentChannel}}
          @directMessages={{directMessages}}
          @memberList={{memberList}}
          @onCreate={{openCreateChannel}}
        />
      {{/unless}}
    </template>
  );

  api.renderInOutlet("after-sidebar-sections", UserPanel);

  // A channel opens in the main area, never a floating panel, so chat
  // runs full page. That's chat's own per-browser preference, so it's set at
  // boot, and again ahead of every route change: chat's drawer shortcut (-)
  // switches it to the drawer just before navigating, and chat's routes read
  // it once the transition is under way.
  // (Reading the preference first would touch the mobile view too early in
  // boot, and setting it is one small local storage write.)
  const chatStateManager = owner.lookup("service:chat-state-manager");
  if (chatStateManager) {
    const preferFullPage = () => chatStateManager.prefersFullPage();

    preferFullPage();
    owner.lookup("service:router").on("routeWillChange", preferFullPage);
  }

  // The category dropdown that would lead to a subcategory is hidden, so a
  // forum channel with subcategories always lists them above its topics, as
  // boxes, since featured topics there would repeat the topic list below.
  // Core's category route reads the setting once the transition is under way.
  owner.lookup("service:router").on("routeWillChange", (transition) => {
    const slugPath = transition.to?.params?.category_slug_path_with_id;
    const category = slugPath && Category.findBySlugPathWithID(slugPath);
    if (category?.isParent) {
      category.show_subcategory_list = true;
      category.subcategory_list_style = "boxes";
    }
  });

  // Core closes the slide-in channel list when one of its sidebar links is
  // tapped, but not when the server menu or a channel's menu navigates from
  // inside it, so close it on any navigation. Through core's header, so it
  // slides out and the page scrolls again.
  const header = owner.lookup("service:header");
  owner.lookup("service:router").on("routeDidChange", () => {
    if (header.hamburgerVisible) {
      owner
        .lookup("service:app-events")
        .trigger("header:keyboard-trigger", { type: "hamburger" });
    }
  });

  if (settings.remember_last_channel && api.getCurrentUser()) {
    new LastChannel(owner, currentChannel, api.getCurrentUser()).install();
  }

  // Chat counts someone online only while chat is open. Here chat is one kind
  // of channel among many, so being anywhere on the site counts. Chat only
  // updates presence on its own routes, so it's told to now.
  const chat = owner.lookup("service:chat");
  if (chat) {
    api.registerValueTransformer("chat-presence-active", () => true);
    chat.updatePresence();
  }

  // Touch screens have no hover for the rows' `…` button, so a long press
  // opens the channel's menu.
  if (api.getCurrentUser()) {
    installLongPress(
      `.sidebar-section[data-section-name^="concord-"] .sidebar-section-link`,
      (row) => {
        const name = row.dataset.linkName;
        const link =
          directory.linkNamed(name) || directMessages.linkNamed(name);
        if (link?.channelKey) {
          channelActions.showChannelMenu(row, link);
        }
      }
    );
  }

  api.addCardClickListenerSelector(".concord-member-list-host");

  // A third column of the main grid, after the page itself.
  api.renderInOutlet(
    "after-main-outlet",
    <template>
      {{#if memberList}}
        {{#unless currentChannel.isAuthPage}}
          <MemberList @memberList={{memberList}} />
        {{/unless}}
      {{/if}}
    </template>
  );

  api.renderInOutlet(
    "after-main-outlet",
    <template>
      {{#if (eq currentChannel.value.type "topic")}}
        <TopicLayout />
      {{/if}}
    </template>
  );

  // The state patch redirects these to the channel panel.
  api.setSidebarPanel("main");
  api.setSeparatedSidebarMode();
});
