import { cached, tracked } from "@glimmer/tracking";
import BasicTopicList from "discourse/components/basic-topic-list";
import icon from "discourse/helpers/d-icon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

const RelatedTopics = <template>
  <div
    role="complementary"
    aria-labelledby="related-topics-title"
    id="related-topics"
    class="more-topics__list"
  >
    <h3 id="related-topics-title" class="more-topics__list-title">
      {{icon "discourse-sparkles"}}{{i18n "discourse_ai.related_topics.title"}}
    </h3>
    <div class="topics">
      <BasicTopicList @topics={{@topic.relatedTopics}} />
    </div>
  </div>
</template>;

export default {
  name: "discourse-ai-related-topics",

  initialize(container) {
    const settings = container.lookup("service:site-settings");

    if (
      !settings.ai_embeddings_enabled ||
      !settings.ai_embeddings_semantic_related_topics_enabled
    ) {
      return;
    }

    withPluginApi("1.37.2", (api) => {
      api.registerMoreTopicsTab({
        id: "related-topics",
        name: i18n("discourse_ai.related_topics.pill"),
        icon: "discourse-sparkles",
        component: RelatedTopics,
        condition: ({ topic }) => topic.relatedTopics?.length,
      });

      api.modifyClass(
        "model:topic",
        (Superclass) =>
          class extends Superclass {
            @tracked related_topics;
            relatedTopicsCache = [];

            @cached
            get relatedTopics() {
              // Used to keep related topics when a user scrolls up from the
              // bottom of the topic and then scrolls back down
              if (this.related_topics) {
                this.relatedTopicsCache = this.related_topics;
              }
              return this.relatedTopicsCache?.map((topic) =>
                this.store.createRecord("topic", topic)
              );
            }
          }
      );

      api.modifyClass(
        "model:post-stream",
        (Superclass) =>
          class extends Superclass {
            _setSuggestedTopics(result) {
              super._setSuggestedTopics(...arguments);
              this.topic.related_topics = result.related_topics;
            }
          }
      );
    });
  },
};
