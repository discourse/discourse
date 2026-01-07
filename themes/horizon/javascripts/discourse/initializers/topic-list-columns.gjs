import { settings } from "virtual:theme";
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
    @topic={{@outletArgs.topic}}
    @hideCategory={{@outletArgs.hideCategory}}
    @bulkSelectEnabled={{@outletArgs.bulkSelectEnabled}}
    @isSelected={{@outletArgs.isSelected}}
    @onBulkSelectToggle={{@outletArgs.onBulkSelectToggle}}
  />
</template>;

export default {
  name: "topic-list-customizations",

  initialize(container) {
    const isDetailed = settings.topic_card_detail === "detailed (experimental)";

    withPluginApi((api) => {
      if (isDetailed) {
        // DETAILED MODE: Use wrapper outlet to replace entire topic list item
        api.renderInOutlet("topic-list-item", DetailedCard);
      } else {
        // SIMPLE MODE: Modify columns
        const router = container.lookup("service:router");
        api.registerValueTransformer(
          "topic-list-columns",
          ({ value: columns }) => {
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
      }

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
