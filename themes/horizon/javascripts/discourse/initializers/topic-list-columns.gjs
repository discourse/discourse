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

const TOPIC_CARD_CONTEXTS = [
  "discovery",
  "suggested",
  "related",
  "group-activity",
  "user-activity",
];

const SIMPLE_CARD_CONTEXTS = ["suggested", "related"];

function isTopicCardContext(listContext) {
  return TOPIC_CARD_CONTEXTS.includes(listContext);
}

function isSimpleCardContext(listContext) {
  return SIMPLE_CARD_CONTEXTS.includes(listContext);
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

  initialize() {
    const isHighContext = settings.topic_card_high_context;

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

      columns.add("topic-activity", {
        item: TopicActivity,
        after: "title",
      });
      columns.delete("posters");
      columns.delete("activity");
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
        "topic-list-class",
        ({ value: classes, context }) => {
          if (isTopicCardContext(context.listContext)) {
            classes.push("--d-topic-cards");
          }
          return classes;
        }
      );

      api.registerValueTransformer(
        "topic-list-columns",
        ({ value: columns, context }) => {
          if (!isTopicCardContext(context.listContext)) {
            return columns;
          }

          isHighContext && !isSimpleCardContext(context.listContext)
            ? applyHighContextLayout(columns)
            : applySimpleLayout(columns);

          return columns;
        }
      );

      api.registerValueTransformer(
        "topic-list-item-class",
        ({ value: classes, context }) => {
          if (!isTopicCardContext(context.listContext)) {
            return classes;
          }

          if (isHighContext && !isSimpleCardContext(context.listContext)) {
            classes.push("--high-context");
          }

          if (context.topic.replyCount > 1) {
            classes.push("--has-replies");
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

      // Disable mobile layout for topic card contexts
      api.registerValueTransformer(
        "topic-list-item-mobile-layout",
        ({ value, context }) => {
          if (isTopicCardContext(context.listContext)) {
            return false;
          }
          return value;
        }
      );

      api.registerBehaviorTransformer(
        "topic-list-item-click",
        ({ context: { event }, next }) => {
          // Check if we're on a topic card route or in a card list context
          // Note: behavior transformer doesn't have listContext in context,
          // so we check for the --d-topic-cards class on the table
          const isCardList = event.target.closest(
            ".topic-list.--d-topic-cards"
          );

          if (!isCardList) {
            return next(); // Use default behavior on non-topic-card routes
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
