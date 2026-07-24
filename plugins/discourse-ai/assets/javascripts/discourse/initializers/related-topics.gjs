import BasicTopicList from "discourse/components/basic-topic-list";
import { withPluginApi } from "discourse/lib/plugin-api";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const RelatedTopics = <template>
  <div
    role="complementary"
    aria-labelledby="related-topics-title"
    id="related-topics"
    class="more-topics__list"
  >
    <h3 id="related-topics-title" class="more-topics__list-title">
      {{dIcon "discourse-sparkles"}}{{i18n "discourse_ai.related_topics.title"}}
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

      api.addModelField("topic", "_relatedTopicsRecords", {
        defaultValue: null,
      });

      // Only updates if we have data - preserves cache when scrolling.
      api.addModelSetter("topic", "related_topics", function (value) {
        if (value?.length) {
          this._relatedTopicsRecords = value.map((topic) =>
            this.store.createRecord("topic", topic)
          );
        }
      });

      api.addModelGetter("topic", "relatedTopics", function () {
        return this._relatedTopicsRecords;
      });

      api.registerBehaviorTransformer(
        "post-stream-suggested-topics",
        ({ context, next }) => {
          next();

          if (context.result.related_topics) {
            context.postStream.topic.related_topics =
              context.result.related_topics;
          }
        }
      );
    });
  },
};
