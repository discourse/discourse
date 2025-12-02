import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BulkSelectTopicsDropdown from "discourse/components/bulk-select-topics-dropdown";
import Post from "discourse/models/post";
import { i18n } from "discourse-i18n";

export default class SearchBulkSelectDropdown extends Component {
  @service dialog;

  get topics() {
    const topics = new Map();
    (this.args.bulkSelectHelper.selected || []).forEach((post) => {
      if (post.topic) {
        topics.set(post.topic.id, post.topic);
      }
    });
    return Array.from(topics.values());
  }

  get topicBulkSelectHelper() {
    const topics = this.topics;
    return {
      selected: topics,
      selectedIds: topics.map((t) => t.id),
      selectedCategoryIds: [
        ...new Set(topics.map((t) => t.category_id).filter(Boolean)),
      ],
      dismissRead: (operationType, options) =>
        this.args.bulkSelectHelper.dismissRead(operationType, options, topics),
      toggleBulkSelect: () => this.args.bulkSelectHelper.toggleBulkSelect(),
    };
  }

  get extraButtons() {
    return [
      {
        id: "delete-topics",
        icon: "trash-can",
        name: i18n("topics.bulk.delete_topics_count", {
          count: this.topics.length,
        }),
        visible: ({ currentUser }) => currentUser?.staff,
      },
      {
        id: "delete-posts",
        icon: "trash-can",
        name: i18n("topics.bulk.delete_posts_count", {
          count: this.args.bulkSelectHelper.selected.length,
        }),
        visible: ({ currentUser }) => currentUser?.staff,
      },
    ];
  }

  @action
  handleAction(actionId) {
    if (actionId === "delete-posts") {
      this.deletePosts();
    }
  }

  @action
  deletePosts() {
    const posts = this.args.bulkSelectHelper.selected;
    if (!posts.length) {
      return;
    }

    this.dialog.confirm({
      message: i18n("topics.bulk.delete_posts_confirmation", {
        count: posts.length,
      }),
      didConfirm: async () => {
        try {
          await Post.deleteMany(posts.map((p) => p.id));
          this.args.bulkSelectHelper.clear();
          await this.args.afterBulkActionComplete?.();
        } catch {
          this.dialog.alert(i18n("generic_error"));
        }
      },
    });
  }

  <template>
    <div class="bulk-select-topics-dropdown">
      <span class="bulk-select-topic-dropdown__count">
        {{i18n
          "topics.bulk.selected_count"
          count=@bulkSelectHelper.selected.length
        }}
      </span>
      <BulkSelectTopicsDropdown
        @bulkSelectHelper={{this.topicBulkSelectHelper}}
        @afterBulkActionComplete={{@afterBulkActionComplete}}
        @extraButtons={{this.extraButtons}}
        @excludedButtonIds={{array "delete-topics"}}
        @onAction={{this.handleAction}}
      />
    </div>
  </template>
}
