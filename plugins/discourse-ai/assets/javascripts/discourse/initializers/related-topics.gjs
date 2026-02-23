import { tracked } from "@glimmer/tracking";
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
      <BasicTopicList @topics={{@topic.relatedTopics}} @listContext="related" />
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

    withPluginApi((api) => {
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
            @tracked _relatedTopicsRecords = null;

            // Only updates if we have data - preserves cache when scrolling.
            set related_topics(value) {
              if (value?.length) {
                this._relatedTopicsRecords = value.map((topic) =>
                  this.store.createRecord("topic", topic)
                );
              }
            }

            get relatedTopics() {
              return this._relatedTopicsRecords;
            }
          }
      );

      api.modifyClass(
        "model:post-stream",
        (Superclass) =>
          class extends Superclass {
            _setSuggestedTopics(result) {
              super._setSuggestedTopics(...arguments);

              if (result.related_topics) {
                this.topic.related_topics = result.related_topics;
              }
            }
          }
      );
    });
  },
};
