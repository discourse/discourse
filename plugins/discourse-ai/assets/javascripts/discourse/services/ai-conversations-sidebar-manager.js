import { tracked } from "@glimmer/tracking";
import { scheduleOnce } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { defaultHomepage } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import AiBotSidebarEmptyState from "../components/ai-bot-sidebar-empty-state";

export const AI_CONVERSATIONS_PANEL = "ai-conversations";
const SCROLL_BUFFER = 100;
const DEBOUNCE = 100;

export default class AiConversationsSidebarManager extends Service {
  @service appEvents;
  @service sidebarState;
  @service messageBus;
  @service routeHistory;
  @service router;

  @tracked topics = [];
  @tracked sections = new TrackedArray();
  @tracked isLoading = true;

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
      this.appEvents.trigger("discourse-ai:force-conversations-sidebar");
    }

    this.sidebarState.isForcingSidebar = true;

    // calling this before fetching data
    // helps avoid flash of main sidebar mode
    this.sidebarState.setPanel(AI_CONVERSATIONS_PANEL);
    this.sidebarState.setSeparatedMode();
    this.sidebarState.hideSwitchPanelButtons();

    // don't render sidebar multiple times
    if (this._didInit) {
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

    const isAdmin = this.sidebarState.currentPanel?.key === ADMIN_PANEL;
    if (this.sidebarState.isForcingSidebar && !isAdmin) {
      this.sidebarState.setPanel(MAIN_PANEL);
      this.sidebarState.isForcingSidebar = false;
      this.appEvents.trigger("discourse-ai:stop-forcing-conversations-sidebar");
    }

    this._removeScrollListener();
  }

  get lastKnownAppURL() {
    const lastForumUrl = this.routeHistory.history.find((url) => {
      return !url.startsWith("/discourse-ai");
    });

    return lastForumUrl || this.router.urlFor(`discovery.${defaultHomepage()}`);
  }

  async fetchMessages() {
    if (this.isFetching || !this.hasMore) {
      return;
    }

    const isFirstPage = this.page === 0;
    this.isFetching = true;

    try {
      let { conversations, meta } = await ajax(
        "/discourse-ai/ai-bot/conversations.json",
        { data: { page: this.page, per_page: 40 } }
      );

      if (isFirstPage) {
        this.topics = conversations;
      } else {
        this.topics = [...this.topics, ...conversations];
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
    this.topics = [topic, ...this.topics];
    this._rebuildSections();
    this._watchForTitleUpdate(topic.id);
  }

  _watchForTitleUpdate(topicId) {
    if (this._subscribedTopicIds?.has(topicId)) {
      return;
    }

    this._subscribedTopicIds = this._subscribedTopicIds || new Set();
    this._subscribedTopicIds.add(topicId);

    const channel = `/discourse-ai/ai-bot/topic/${topicId}`;

    this.messageBus.subscribe(channel, (payload) => {
      this._applyTitleUpdate(topicId, payload.title);
      this.messageBus.unsubscribe(channel);
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

    const todaySection = {
      name: "today",
      title: i18n("discourse_ai.ai_bot.conversations.today"),
      links: new TrackedArray(),
    };

    fresh.push(todaySection);

    this.topics.forEach((t) => {
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
        sec = { name: dateGroup, title, links: new TrackedArray() };
        fresh.push(sec);
      }

      sec.links.push({
        key: t.id,
        route: "topic.fromParamsNear",
        models: [t.slug, t.id, t.last_read_post_number || 0],
        title: t.title,
        text: t.title,
        classNames: `ai-conversation-${t.id}`,
      });
    });

    this.sections = new TrackedArray(fresh);

    // register each new section once
    for (let sec of fresh) {
      if (this._registered.has(sec.name)) {
        continue;
      }
      this._registered.add(sec.name);

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
            return htmlSafe(sec.title);
          }

          get links() {
            return (
              this.manager.sections.find((s) => s.name === sec.name)?.links ||
              []
            );
          }

          get emptyStateComponent() {
            if (!this.manager.isLoading && this.links.length === 0) {
              return AiBotSidebarEmptyState;
            }
          }
        };
      }, AI_CONVERSATIONS_PANEL);
    }
  }
}
