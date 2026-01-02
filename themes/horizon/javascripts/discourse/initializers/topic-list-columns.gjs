import { settings } from "virtual:theme";
import SortableColumn from "discourse/components/topic-list/header/sortable-column";
import { withPluginApi } from "discourse/lib/plugin-api";
import DetailedTopicCard from "../components/card/detailed-topic-card";
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

const DetailedCard = <template>
  <DetailedTopicCard
    @topic={{@topic}}
    @hideCategory={{@hideCategory}}
    @bulkSelectEnabled={{@bulkSelectEnabled}}
    @isSelected={{@isSelected}}
    @onBulkSelectToggle={{@onBulkSelectToggle}}
  />
</template>;

const DetailedCardHeader = <template>
  <SortableColumn
    @order="default"
    @category={{@category}}
    @activeOrder={{@activeOrder}}
    @changeSort={{@changeSort}}
    @ascending={{@ascending}}
    @name={{@name}}
    @bulkSelectEnabled={{@bulkSelectEnabled}}
    @showBulkToggle={{@showBulkToggle}}
    @canBulkSelect={{@canBulkSelect}}
    @canDoBulkActions={{@canDoBulkActions}}
    @bulkSelectHelper={{@bulkSelectHelper}}
  />
</template>;

export default {
  name: "topic-list-customizations",

  initialize(container) {
    const router = container.lookup("service:router");
    const isDetailed = settings.topic_card_detail === "detailed";

    withPluginApi((api) => {
      api.registerValueTransformer(
        "topic-list-columns",
        ({ value: columns }) => {
          if (isDetailed) {
            // DETAILED MODE: Single column with full card
            const hasBulkSelect = columns.has("bulk-select");

            // Clear all columns except bulk-select
            for (const [key] of columns.entries()) {
              if (key !== "bulk-select") {
                columns.delete(key);
              }
            }

            // Add detailed card
            columns.add("detailed-card", {
              header: DetailedCardHeader,
              item: DetailedCard,
              after: hasBulkSelect ? "bulk-select" : undefined,
            });

            return columns;
          }

          // SIMPLE MODE: Existing implementation
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
          return columns;
        }
      );

      api.registerValueTransformer(
        "topic-list-item-class",
        ({ value: classes, context }) => {
          if (isDetailed) {
            classes.push("--high-context");
          }

          if (
            context.topic.is_hot ||
            context.topic.pinned ||
            context.topic.pinned_globally
          ) {
            classes.push("--has-status-card");
          }
          if (context.topic.replyCount > 1) {
            classes.push("has-replies");
          }
          return classes;
        }
      );

      api.registerValueTransformer("topic-list-item-mobile-layout", () => {
        return false;
      });

      api.registerBehaviorTransformer(
        "topic-list-item-click",
        ({ context: { event }, next }) => {
          if (event.target.closest("a, button, input")) {
            return next();
          }

          event.preventDefault();
          event.stopPropagation();

          const topicLink = event.target
            .closest("tr")
            .querySelector("a.raw-topic-link");

          // Redespatch the click on the topic link, so that all key-handing is sorted
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
