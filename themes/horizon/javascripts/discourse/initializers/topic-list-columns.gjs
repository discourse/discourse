import { settings } from "virtual:theme";
import { withPluginApi } from "discourse/lib/plugin-api";
import HighContextTopicCard from "../components/card/high-context-topic-card";
import TopicActivityColumn from "../components/card/topic-activity-column";
import TopicCategoryColumn from "../components/card/topic-category-column";
import TopicCreatorColumn from "../components/card/topic-creator-column";
import TopicRepliesColumn from "../components/card/topic-replies-column";
import TopicStatusColumn from "../components/card/topic-status-column";

const TopicActivity = <template>
  <td class="topic-activity-data">
    <TopicActivityColumn @topic={{@topic}} />
  </td>
</template>;

const TopicStatus = <template>
  <td class="topic-status-data">
    <TopicStatusColumn @topic={{@topic}} />
  </td>
</template>;

const TopicCategory = <template>
  <td class="topic-category-data">
    <TopicCategoryColumn @topic={{@topic}} />
  </td>
</template>;

const TopicReplies = <template>
  <td class="topic-likes-replies-data">
    <TopicRepliesColumn @topic={{@topic}} />
  </td>
</template>;

const TopicCreator = <template>
  <td class="topic-creator-data">
    <TopicCreatorColumn @topic={{@topic}} />
  </td>
</template>;

function isHighContextRoute(routeName) {
  if (!routeName) {
    return false;
  }

  // Only show high context cards on public topic list routes
  // Discovery routes: /latest, /new, /unread, /top, /hot, /c/:category
  if (routeName.startsWith("discovery")) {
    return true;
  }

  // Tag routes: /tag/:tag_name
  if (routeName.startsWith("tag")) {
    return true;
  }

  return false;
}

const HighContextCard = <template>
  <HighContextTopicCard
    @topic={{@topic}}
    @hideCategory={{@hideCategory}}
    @bulkSelectEnabled={{@bulkSelectEnabled}}
    @isSelected={{@isSelected}}
    @onBulkSelectToggle={{@onBulkSelectToggle}}
  />
</template>;

export default {
  name: "topic-list-customizations",

  initialize(container) {
    const isHighContext = settings.topic_card_context === "high_context";
    const router = container.lookup("service:router");

    function applySimpleLayout(columns) {
      columns.add("topic-status", {
        item: TopicStatus,
        after: "topic-author",
      });
      columns.add("topic-category", {
        item: TopicCategory,
        after: "topic-status",
      });
      columns.add("topic-likes-replies", {
        item: TopicReplies,
        after: "topic-author-avatar",
      });
      columns.add("topic-creator", {
        item: TopicCreator,
        after: "topic-author-avatar",
      });

      columns.delete("views");
      columns.delete("replies");

      if (!router.currentRouteName.includes("userPrivateMessages")) {
        columns.add("topic-activity", {
          item: TopicActivity,
          after: "title",
        });
        columns.delete("posters");
        columns.delete("activity");
      }
    }

    function applyHighContextLayout(columns) {
      columns.delete("bulk-select");
      columns.delete("topic");
      columns.delete("posters");
      columns.delete("replies");
      columns.delete("views");
      columns.delete("activity");
      columns.add("high-context-card", {
        item: HighContextCard,
      });
    }

    withPluginApi((api) => {
      api.registerValueTransformer(
        "topic-list-columns",
        ({ value: columns }) => {
          if (isHighContext && isHighContextRoute(router.currentRouteName)) {
            applyHighContextLayout(columns);
          } else {
            applySimpleLayout(columns);
          }
          return columns;
        }
      );

      api.registerValueTransformer(
        "topic-list-item-class",
        ({ value: classes, context }) => {
          // has-replies is needed for grid layout on all routes (including PMs)
          if (context.topic.replyCount > 1) {
            classes.push("has-replies");
          }

          // The rest only applies to public topic list routes
          if (!isHighContextRoute(router.currentRouteName)) {
            return classes;
          }

          if (isHighContext) {
            classes.push("--high-context");
          }

          if (
            context.topic.is_hot ||
            context.topic.pinned ||
            context.topic.pinned_globally
          ) {
            classes.push("--has-status-card");
          }

          return classes;
        }
      );

      // Force desktop layout on public topic lists for Horizon card styling.
      // Return undefined on other routes to preserve default mobile/desktop behavior.
      api.registerValueTransformer("topic-list-item-mobile-layout", () => {
        if (isHighContextRoute(router.currentRouteName)) {
          return false;
        }
      });

      api.registerBehaviorTransformer(
        "topic-list-item-click",
        ({ context: { event }, next }) => {
          if (!isHighContextRoute(router.currentRouteName)) {
            return next(); // Use default behavior on non-public routes
          }

          if (event.target.closest("a, button, input")) {
            return next();
          }

          event.preventDefault();
          event.stopPropagation();

          const topicLink = event.target
            .closest("tr")
            .querySelector("a.raw-topic-link");

          // Redispatch the click on the topic link, so that all key-handing is sorted
          topicLink.dispatchEvent(
            new MouseEvent("click", {
              ctrlKey: event.ctrlKey,
              metaKey: event.metaKey,
              shiftKey: event.shiftKey,
              button: event.button,
              which: event.which,
              bubbles: true,
              cancelable: true,
            })
          );
        }
      );
    });
  },
};
