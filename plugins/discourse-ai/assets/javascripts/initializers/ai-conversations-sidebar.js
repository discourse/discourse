import { tracked } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import AiBotSidebarEmptyState from "../discourse/components/ai-bot-sidebar-empty-state";
import AiBotSidebarNewConversation from "../discourse/components/ai-bot-sidebar-new-conversation";
import { AI_CONVERSATIONS_PANEL } from "../discourse/services/ai-conversations-sidebar-manager";

export default {
  name: "ai-conversations-sidebar",

  initialize() {
    withPluginApi((api) => {
      const siteSettings = api.container.lookup("service:site-settings");
      if (!siteSettings.ai_bot_enable_dedicated_ux) {
        return;
      }

      const currentUser = api.container.lookup("service:current-user");
      if (!currentUser) {
        return;
      }

      const aiConversationsSidebarManager = api.container.lookup(
        "service:ai-conversations-sidebar-manager"
      );
      const appEvents = api.container.lookup("service:app-events");
      const messageBus = api.container.lookup("service:message-bus");

      api.addSidebarPanel(
        (BaseCustomSidebarPanel) =>
          class AiConversationsSidebarPanel extends BaseCustomSidebarPanel {
            key = AI_CONVERSATIONS_PANEL;
            hidden = true;
            displayHeader = false; // this would add a misplaced back to forum button
            expandActiveSection = true;
          }
      );

      api.renderInOutlet(
        "before-sidebar-sections",
        AiBotSidebarNewConversation
      );
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          const AiConversationLink = class extends BaseCustomSidebarSectionLink {
            route = "topic.fromParamsNear";

            constructor(topic) {
              super(...arguments);
              this.topic = topic;
            }

            get key() {
              return this.topic.id;
            }

            get name() {
              return this.topic.title;
            }

            get models() {
              return [
                this.topic.slug,
                this.topic.id,
                this.topic.last_read_post_number || 0,
              ];
            }

            get title() {
              return this.topic.title;
            }

            get text() {
              return this.topic.title;
            }

            get classNames() {
              return `ai-conversation-${this.topic.id}`;
            }
          };

          return class extends BaseCustomSidebarSection {
            @tracked links = new TrackedArray();
            @tracked topics = [];
            @tracked hasMore = [];
            @tracked loadedTodayLabel = false;
            @tracked loadedSevenDayLabel = false;
            @tracked loadedThirtyDayLabel = false;
            @tracked loadedMonthLabels = new Set();
            @tracked isLoading = true;
            isFetching = false;
            page = 0;
            totalTopicsCount = 0;

            constructor() {
              super(...arguments);
              this.fetchMessages();

              appEvents.on(
                "discourse-ai:bot-pm-created",
                this,
                "addNewPMToSidebar"
              );
            }

            @bind
            willDestroy() {
              this.removeScrollListener();
              appEvents.off(
                "discourse-ai:bot-pm-created",
                this,
                "addNewPMToSidebar"
              );
            }

            get name() {
              return "ai-conversations-history";
            }

            get emptyStateComponent() {
              if (!this.isLoading) {
                return AiBotSidebarEmptyState;
              }
            }

            get text() {
              return i18n(
                "discourse_ai.ai_bot.conversations.messages_sidebar_title"
              );
            }

            get sidebarElement() {
              return document.querySelector(
                ".sidebar-wrapper .sidebar-sections"
              );
            }

            addNewPMToSidebar(topic) {
              // Reset category labels since we're adding a new topic
              this.loadedTodayLabel = false;
              this.loadedSevenDayLabel = false;
              this.loadedThirtyDayLabel = false;
              this.loadedMonthLabels.clear();

              this.topics = [topic, ...this.topics];
              this.buildSidebarLinks();

              this.watchForTitleUpdate(topic);
            }

            @bind
            removeScrollListener() {
              const sidebar = this.sidebarElement;
              if (sidebar) {
                sidebar.removeEventListener("scroll", this.scrollHandler);
              }
            }

            @bind
            attachScrollListener() {
              const sidebar = this.sidebarElement;
              if (sidebar) {
                sidebar.addEventListener("scroll", this.scrollHandler);
              }
            }

            @bind
            scrollHandler() {
              const sidebarElement = this.sidebarElement;
              if (!sidebarElement) {
                return;
              }

              const scrollPosition = sidebarElement.scrollTop;
              const scrollHeight = sidebarElement.scrollHeight;
              const clientHeight = sidebarElement.clientHeight;

              // When user has scrolled to bottom with a small threshold
              if (scrollHeight - scrollPosition - clientHeight < 100) {
                if (this.hasMore && !this.isFetching) {
                  this.loadMore();
                }
              }
            }

            async fetchMessages(isLoadingMore = false) {
              if (this.isFetching) {
                return;
              }

              try {
                this.isFetching = true;
                const data = await ajax(
                  "/discourse-ai/ai-bot/conversations.json",
                  {
                    data: { page: this.page, per_page: 40 },
                  }
                );

                if (isLoadingMore) {
                  this.topics = [...this.topics, ...data.conversations];
                } else {
                  this.topics = data.conversations;
                }

                this.totalTopicsCount = data.meta.total;
                this.hasMore = data.meta.has_more;
                this.isFetching = false;
                this.removeScrollListener();
                this.buildSidebarLinks();
                this.attachScrollListener();
              } catch {
                this.isFetching = false;
              } finally {
                this.isLoading = false;
              }
            }

            loadMore() {
              if (this.isFetching || !this.hasMore) {
                return;
              }

              this.page = this.page + 1;
              this.fetchMessages(true);
            }

            groupByDate(topic) {
              const now = new Date();
              const lastPostedAt = new Date(topic.last_posted_at);
              const daysDiff = Math.round(
                (now - lastPostedAt) / (1000 * 60 * 60 * 24)
              );

              if (daysDiff <= 1 || !topic.last_posted_at) {
                if (!this.loadedTodayLabel) {
                  this.loadedTodayLabel = true;
                  return {
                    text: i18n("discourse_ai.ai_bot.conversations.today"),
                    classNames: "date-heading",
                    name: "date-heading-today",
                  };
                }
              }
              // Last 7 days group
              else if (daysDiff <= 7) {
                if (!this.loadedSevenDayLabel) {
                  this.loadedSevenDayLabel = true;
                  return {
                    text: i18n("discourse_ai.ai_bot.conversations.last_7_days"),
                    classNames: "date-heading",
                    name: "date-heading-last-7-days",
                  };
                }
              }
              // Last 30 days group
              else if (daysDiff <= 30) {
                if (!this.loadedThirtyDayLabel) {
                  this.loadedThirtyDayLabel = true;
                  return {
                    text: i18n(
                      "discourse_ai.ai_bot.conversations.last_30_days"
                    ),
                    classNames: "date-heading",
                    name: "date-heading-last-30-days",
                  };
                }
              }
              // Group by month for older conversations
              else {
                const month = lastPostedAt.getMonth();
                const year = lastPostedAt.getFullYear();
                const monthKey = `${year}-${month}`;

                if (!this.loadedMonthLabels.has(monthKey)) {
                  this.loadedMonthLabels.add(monthKey);

                  const formattedDate = autoUpdatingRelativeAge(
                    new Date(topic.last_posted_at)
                  );

                  return {
                    text: htmlSafe(formattedDate),
                    classNames: "date-heading",
                    name: `date-heading-${monthKey}`,
                  };
                }
              }
            }

            buildSidebarLinks() {
              // Reset date header tracking
              this.loadedTodayLabel = false;
              this.loadedSevenDayLabel = false;
              this.loadedThirtyDayLabel = false;
              this.loadedMonthLabels.clear();

              this.links = [...this.topics].flatMap((topic) => {
                const dateLabel = this.groupByDate(topic);
                return dateLabel
                  ? [dateLabel, new AiConversationLink(topic)]
                  : [new AiConversationLink(topic)];
              });
            }

            watchForTitleUpdate(topic) {
              const channel = `/discourse-ai/ai-bot/topic/${topic.id}`;
              const callback = this.updateTopicTitle.bind(this);
              messageBus.subscribe(channel, ({ title }) => {
                callback(topic, title);
                messageBus.unsubscribe(channel);
              });
            }

            updateTopicTitle(topic, title) {
              // update the data
              topic.title = title;

              // force Glimmer to re-render that one link
              this.links = this.links.map((link) =>
                link?.topic?.id === topic.id
                  ? new AiConversationLink(topic)
                  : link
              );
            }
          };
        },
        AI_CONVERSATIONS_PANEL
      );

      const setSidebarPanel = (transition) => {
        if (transition?.to?.name === "discourse-ai-bot-conversations") {
          return aiConversationsSidebarManager.forceCustomSidebar();
        }

        const topic = api.container.lookup("controller:topic").model;
        // if the topic is not a private message, not created by the current user,
        // or doesn't have a bot response, we don't need to override sidebar
        if (
          topic?.archetype === "private_message" &&
          topic.user_id === currentUser.id &&
          topic.is_bot_pm
        ) {
          return aiConversationsSidebarManager.forceCustomSidebar();
        }

        // newTopicForceSidebar is set to true when a new topic is created. We have
        // this because the condition `postStream.posts` above will not be true as the bot response
        // is not in the postStream yet when this initializer is ran. So we need to force
        // the sidebar to open when creating a new topic. After that, we set it to false again.
        if (aiConversationsSidebarManager.newTopicForceSidebar) {
          aiConversationsSidebarManager.newTopicForceSidebar = false;
          return aiConversationsSidebarManager.forceCustomSidebar();
        }

        aiConversationsSidebarManager.stopForcingCustomSidebar();
      };

      api.container
        .lookup("service:router")
        .on("routeDidChange", setSidebarPanel);
    });
  },
};
