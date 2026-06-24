import { tracked } from "@glimmer/tracking";
import { trackedArray } from "@ember/reactive/collections";
import { scheduleOnce } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { defaultHomepage } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import AiBotSidebarEmptyState from "../components/ai-bot-sidebar-empty-state";
import AiConversationSidebarContextMenu from "../components/ai-conversation-sidebar-context-menu";

export const AI_CONVERSATIONS_PANEL = "ai-conversations";
const SCROLL_BUFFER = 100;
const DEBOUNCE = 100;
const TITLE_CHANNEL = `/discourse-ai/ai-bot/topic-titles`;

export default class AiConversationsSidebarManager extends Service {
  @service appEvents;
  @service sidebarState;
  @service messageBus;
  @service routeHistory;
  @service router;
  @service menu;
  @service capabilities;
  @service currentUser;
  @service siteSettings;

  @tracked topics = [];
  @tracked sections = trackedArray();
  @tracked isLoading = true;
  @tracked lastKnownAppURL = null;

  api = null;
  isFetching = false;
  page = 0;
  hasMore = true;
  _registered = new Set();
  _hasScrollListener = false;
  _scrollElement = null;
  _didInit = false;

  _debouncedScrollHandler = () => {
    discourseDebounce(
      this,
      () => {
        const element = this._scrollElement;
        if (!element) {
          return;
        }

        const { scrollTop, scrollHeight, clientHeight } = element;
        if (
          scrollHeight - scrollTop - clientHeight - SCROLL_BUFFER < 100 &&
          !this.isFetching &&
          this.hasMore
        ) {
          this.fetchMessages();
        }
      },
      DEBOUNCE
    );
  };

  constructor() {
    super(...arguments);

    this.appEvents.on(
      "discourse-ai:bot-pm-created",
      this,
      this._handleNewBotPM
    );

    this.appEvents.on(
      "discourse-ai:conversations-sidebar-updated",
      this,
      this._attachScrollListener
    );

    this._watchForTitleUpdates();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "discourse-ai:bot-pm-created",
      this,
      this._handleNewBotPM
    );
    this.appEvents.off(
      "discourse-ai:conversations-sidebar-updated",
      this,
      this._attachScrollListener
    );

    this.messageBus.unsubscribe(TITLE_CHANNEL);
  }

  addEmptyStateClass() {
    document.body.classList.toggle(
      "has-empty-ai-conversations-sidebar",
      !this.topics.length
    );
  }

  forceCustomSidebar() {
    document.body.classList.add("has-ai-conversations-sidebar");
    if (!this.sidebarState.isForcingSidebar) {
      this._captureLastKnownAppURL();
      this.appEvents.trigger("discourse-ai:force-conversations-sidebar");
    }

    this.sidebarState.isForcingSidebar = true;
    this.sidebarState.forcingSidebarPanel = AI_CONVERSATIONS_PANEL;

    // calling this before fetching data
    // helps avoid flash of main sidebar mode
    this.sidebarState.setPanel(AI_CONVERSATIONS_PANEL);
    this.sidebarState.setSeparatedMode();
    this.sidebarState.hideSwitchPanelButtons();

    // don't render sidebar multiple times
    if (this._didInit) {
      this._rebuildSections();
      this.addEmptyStateClass();
      return true;
    }

    this._didInit = true;

    this.fetchMessages().then(() => {
      this.sidebarState.setPanel(AI_CONVERSATIONS_PANEL);
      this.addEmptyStateClass();
    });

    return true;
  }

  _attachScrollListener() {
    const sections = document.querySelector(
      ".sidebar-sections.ai-conversations-panel"
    );
    this._scrollElement = sections;

    if (this._hasScrollListener || !this._scrollElement) {
      return;
    }

    sections.addEventListener("scroll", this._debouncedScrollHandler);

    this._hasScrollListener = true;
  }

  _removeScrollListener() {
    if (this._hasScrollListener) {
      this._scrollElement.removeEventListener(
        "scroll",
        this._debouncedScrollHandler
      );
      this._hasScrollListener = false;
      this._scrollElement = null;
    }
  }

  stopForcingCustomSidebar() {
    document.body.classList.remove("has-ai-conversations-sidebar");
    document.body.classList.remove("has-empty-ai-conversations-sidebar");

    const isStillAiPanel =
      this.sidebarState.currentPanel?.key === AI_CONVERSATIONS_PANEL;

    // Only clear forcing if we were the ones who set it
    const weSetForcing =
      this.sidebarState.forcingSidebarPanel === AI_CONVERSATIONS_PANEL;

    if (this.sidebarState.isForcingSidebar && weSetForcing) {
      if (isStillAiPanel) {
        // No other route claimed the sidebar, reset to main panel
        this.sidebarState.setPanel(MAIN_PANEL);
      }
      // Clear the forcing flag since we set it and we're leaving
      this.sidebarState.isForcingSidebar = false;
      this.sidebarState.forcingSidebarPanel = null;
      this.appEvents.trigger("discourse-ai:stop-forcing-conversations-sidebar");
    }

    this._removeScrollListener();
  }

  _captureLastKnownAppURL() {
    const lastForumUrl = this.routeHistory.history.find((url) => {
      return !url.startsWith("/discourse-ai");
    });

    this.lastKnownAppURL =
      lastForumUrl || this.router.urlFor(`discovery.${defaultHomepage()}`);
  }

  async fetchMessages() {
    if (this.isFetching || !this.hasMore) {
      return;
    }

    const isFirstPage = this.page === 0;
    this.isFetching = true;

    try {
      let { conversations, starred_conversations, meta } = await ajax(
        "/discourse-ai/ai-bot/conversations.json",
        { data: { page: this.page, per_page: 40 } }
      );

      starred_conversations ||= [];
      conversations ||= [];

      if (isFirstPage) {
        this.topics = this._dedupeTopics([
          ...starred_conversations,
          ...conversations,
        ]);
      } else {
        this.topics = this._dedupeTopics([...this.topics, ...conversations]);
        // force rerender when fetching more messages
        this.sidebarState.setPanel(AI_CONVERSATIONS_PANEL);
      }

      this.page += 1;
      this.hasMore = meta.has_more;

      this._rebuildSections();
    } finally {
      this.isFetching = false;
      this.isLoading = false;
    }
  }

  _handleNewBotPM(topic) {
    this.topics = this._dedupeTopics([
      { ai_conversation_starred: false, ...topic },
      ...this.topics,
    ]);
    this._rebuildSections();
  }

  async updateConversationStarred(topic, starred) {
    if (!topic) {
      return;
    }

    const previousValue = !!topic.ai_conversation_starred;
    const updatedTopic = {
      ...topic,
      ai_conversation_starred: starred,
      ai_conversation_starred_at: starred
        ? topic.ai_conversation_starred_at || new Date().toISOString()
        : null,
    };

    this._updateTopic(updatedTopic);

    try {
      let response = await ajax(
        `/discourse-ai/ai-bot/conversations/${topic.id}/starred.json`,
        { type: "PUT", data: { starred } }
      );

      this._updateTopic({
        ...updatedTopic,
        ai_conversation_starred: response.starred,
      });
    } catch (error) {
      this._updateTopic({
        ...topic,
        ai_conversation_starred: previousValue,
        ai_conversation_starred_at: topic.ai_conversation_starred_at,
      });
      popupAjaxError(error);
      throw error;
    }
  }

  _dedupeTopics(topics) {
    const seen = new Set();
    return topics.filter((topic) => {
      if (seen.has(topic.id)) {
        return false;
      }

      seen.add(topic.id);
      return true;
    });
  }

  _updateTopic(topic) {
    if (this.topics.some((t) => t.id === topic.id)) {
      this.topics = this.topics.map((t) => (t.id === topic.id ? topic : t));
    } else {
      this.topics = [topic, ...this.topics];
    }

    this._rebuildSections();
  }

  _watchForTitleUpdates() {
    this.messageBus.subscribe(TITLE_CHANNEL, (payload) => {
      this._applyTitleUpdate(payload.topic_id, payload.title);
    });
  }

  _applyTitleUpdate(topicId, newTitle) {
    this.topics = this.topics.map((t) =>
      t.id === topicId ? { ...t, title: newTitle } : t
    );

    this._rebuildSections();
  }

  // organize by date and create a section for each date group
  _rebuildSections() {
    const now = Date.now();
    const fresh = [];
    const starredTopics = this.topics
      .filter((t) => t.ai_conversation_starred)
      .sort((a, b) => {
        const bDate = new Date(
          b.ai_conversation_starred_at || b.last_posted_at || now
        );
        const aDate = new Date(
          a.ai_conversation_starred_at || a.last_posted_at || now
        );
        return bDate - aDate;
      });

    if (this.siteSettings.enable_ai_bot_starred_conversations) {
      fresh.push({
        name: "starred-conversations",
        title: i18n("discourse_ai.ai_bot.conversations.starred"),
        links: trackedArray(
          starredTopics.map((t) => this._conversationLink(t))
        ),
      });
    }

    const todaySection = {
      name: "today",
      title: i18n("discourse_ai.ai_bot.conversations.today"),
      links: trackedArray(),
    };

    fresh.push(todaySection);

    this.topics
      .filter(
        (t) =>
          !this.siteSettings.enable_ai_bot_starred_conversations ||
          !t.ai_conversation_starred
      )
      .sort((a, b) => {
        const bDate = new Date(b.last_posted_at || now);
        const aDate = new Date(a.last_posted_at || now);
        return bDate - aDate;
      })
      .forEach((t) => {
        const postedAtMs = new Date(t.last_posted_at || now).valueOf();
        const diffDays = Math.floor((now - postedAtMs) / 86400000);
        let dateGroup;

        if (diffDays <= 1) {
          dateGroup = "today";
        } else if (diffDays <= 7) {
          dateGroup = "last-7-days";
        } else if (diffDays <= 30) {
          dateGroup = "last-30-days";
        } else {
          const d = new Date(postedAtMs);
          const key = `${d.getFullYear()}-${d.getMonth()}`;
          dateGroup = key;
        }

        let sec;
        if (dateGroup === "today") {
          sec = todaySection;
        } else {
          sec = fresh.find((s) => s.name === dateGroup);
        }

        if (!sec) {
          let title;
          switch (dateGroup) {
            case "last-7-days":
              title = i18n("discourse_ai.ai_bot.conversations.last_7_days");
              break;
            case "last-30-days":
              title = i18n("discourse_ai.ai_bot.conversations.last_30_days");
              break;
            default:
              title = autoUpdatingRelativeAge(new Date(t.last_posted_at));
          }
          sec = { name: dateGroup, title, links: trackedArray() };
          fresh.push(sec);
        }

        sec.links.push(this._conversationLink(t));
      });

    this.sections = trackedArray(fresh);

    let registeredNewSection = false;

    // register each new section once
    for (let sec of fresh) {
      if (this._registered.has(sec.name)) {
        continue;
      }
      this._registered.add(sec.name);
      registeredNewSection = true;

      this.api.addSidebarSection((BaseCustomSidebarSection) => {
        return class extends BaseCustomSidebarSection {
          @service("ai-conversations-sidebar-manager") manager;
          @service("appEvents") events;

          constructor() {
            super(...arguments);
            scheduleOnce("afterRender", this, this.triggerEvent);
          }

          triggerEvent() {
            this.events.trigger("discourse-ai:conversations-sidebar-updated");
          }

          get name() {
            return sec.name;
          }

          get title() {
            return sec.title;
          }

          get text() {
            return trustHTML(sec.title);
          }

          get links() {
            return (
              this.manager.sections.find((s) => s.name === sec.name)?.links ||
              []
            );
          }

          get displaySection() {
            const currentSection = this.manager.sections.find(
              (s) => s.name === sec.name
            );

            if (!currentSection) {
              return false;
            }

            if (sec.name === "starred-conversations") {
              return currentSection.links.length > 0;
            }

            return true;
          }

          get emptyStateComponent() {
            if (!this.manager.isLoading && this.links.length === 0) {
              return AiBotSidebarEmptyState;
            }
          }
        };
      }, AI_CONVERSATIONS_PANEL);
    }

    if (
      registeredNewSection &&
      this.sidebarState.currentPanel?.key === AI_CONVERSATIONS_PANEL
    ) {
      this.sidebarState.setPanel(AI_CONVERSATIONS_PANEL);
    }
  }

  _conversationLink(topic) {
    const isStarred = !!topic.ai_conversation_starred;
    const canShowConversationMenu =
      (this.siteSettings.enable_ai_bot_starred_conversations ||
        this.currentUser?.can_share_ai_bot_conversations) &&
      !this.capabilities.isIpadOS;

    return {
      key: topic.id,
      name: `ai-conversation-${topic.id}`,
      route: "topic.fromParamsNear",
      models: [topic.slug, topic.id, topic.last_read_post_number || 0],
      currentWhen: this._isCurrentTopic(topic) ? true : undefined,
      title: topic.title,
      text: topic.title,
      classNames: `ai-conversation-sidebar__link ai-conversation-${topic.id}${
        isStarred ? " ai-conversation-sidebar__link--starred" : ""
      }`,
      suffixType: null,
      suffixValue: null,
      suffixCSSClass: null,
      hoverType: canShowConversationMenu ? "icon" : null,
      hoverValue: canShowConversationMenu ? "ellipsis-vertical" : null,
      hoverTitle: canShowConversationMenu
        ? i18n("discourse_ai.ai_bot.conversations.open_conversation_menu")
        : null,
      hoverAction: canShowConversationMenu
        ? (event, onMenuClose) => {
            event.preventDefault();
            event.stopPropagation();

            this.menu.show(event.target, {
              identifier: "ai-conversation-menu",
              component: AiConversationSidebarContextMenu,
              placement: "right",
              data: { topic, manager: this },
              onClose: onMenuClose,
            });
          }
        : null,
    };
  }

  _isCurrentTopic(topic) {
    return this._currentTopicId() === topic.id;
  }

  _currentTopicId() {
    let route = this.router.currentRoute;

    while (route) {
      const id = parseInt(route.params?.id, 10);

      if (id) {
        return id;
      }

      route = route.parent;
    }
  }
}
