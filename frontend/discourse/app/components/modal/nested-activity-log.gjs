import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import NestedActivityLogItem from "discourse/components/modal/nested-activity-log/item";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class NestedActivityLog extends Component {
  @service a11y;
  @service appEvents;
  @service currentUser;
  @service dialog;
  @service store;

  @tracked loading = true;
  @tracked loadingMore = false;
  @tracked smallActions = [];
  @tracked page = 0;
  @tracked hasMore = false;

  // Bumped on every refresh so in-flight responses from a superseded fetch
  // (e.g. a load-more racing a message-bus refresh) are discarded.
  #requestGeneration = 0;

  constructor() {
    super(...arguments);
    this.fetchActivity();
    this.appEvents.on(
      "nested-replies:activity-changed",
      this,
      this.handleActivityChanged
    );
  }

  willDestroy() {
    this.#requestGeneration++;
    this.appEvents.off(
      "nested-replies:activity-changed",
      this,
      this.handleActivityChanged
    );
    super.willDestroy(...arguments);
  }

  handleActivityChanged({ topicId }) {
    if (String(topicId) !== String(this.args.model.topic.id)) {
      return;
    }

    this.fetchActivity({ announce: true });
  }

  @action
  async fetchActivity({ announce = false } = {}) {
    const generation = ++this.#requestGeneration;
    const isInitialLoad = this.smallActions.length === 0;
    if (isInitialLoad) {
      this.loading = true;
    }

    try {
      // Re-fetch every page the user had loaded so a refresh doesn't
      // collapse the list back to the first page.
      const pagesLoaded = this.page + 1;
      const actions = [];
      let page = 0;
      let hasMore = false;

      do {
        const data = await this.#fetchPage(page);
        if (generation !== this.#requestGeneration) {
          return;
        }
        actions.push(...this.#hydrateActions(data.small_actions));
        hasMore = data.has_more;
        page += 1;
      } while (hasMore && page < pagesLoaded);

      this.page = page - 1;
      this.hasMore = hasMore;
      this.smallActions = actions;

      if (announce) {
        this.a11y.announce(
          i18n("nested_replies.activity_log.updated"),
          "polite"
        );
      }
    } catch (e) {
      if (generation === this.#requestGeneration) {
        popupAjaxError(e);
      }
    } finally {
      if (isInitialLoad && generation === this.#requestGeneration) {
        this.loading = false;
      }
    }
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.hasMore) {
      return;
    }

    const generation = this.#requestGeneration;
    this.loadingMore = true;
    try {
      const nextPage = this.page + 1;
      const data = await this.#fetchPage(nextPage);
      if (generation !== this.#requestGeneration) {
        return;
      }
      this.page = nextPage;
      this.hasMore = data.has_more;
      this.smallActions = [
        ...this.smallActions,
        ...this.#hydrateActions(data.small_actions),
      ];
    } catch (e) {
      if (generation === this.#requestGeneration) {
        popupAjaxError(e);
      }
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  editPost(post) {
    this.args.closeModal();
    this.args.model.editPost(post);
  }

  @action
  deletePost(post) {
    if (!post.canDelete) {
      return;
    }

    this.dialog.yesNoConfirm({
      message: i18n("post.confirm_delete"),
      didConfirm: async () => {
        try {
          await post.destroy(this.currentUser);
          await this.fetchActivity();
        } catch (error) {
          post.undoDeleteState();
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  async recoverPost(post) {
    await post.recover();
    await this.fetchActivity();
  }

  async #fetchPage(page) {
    const topic = this.args.model.topic;
    return await ajax(`/n/${topic.slug}/${topic.id}/activity.json`, {
      data: { page },
    });
  }

  #hydrateActions(actions = []) {
    return actions.map((activity) => {
      if (activity.synthetic) {
        return activity;
      }

      const topic = this.args.model.topic;
      const post = this.store.createRecord("post", {
        ...activity,
        topic,
        action_code_path: activity.action_code_path || `/t/${topic.id}`,
      });
      post.topic = topic;
      return post;
    });
  }

  <template>
    <DModal
      @title={{i18n "nested_replies.activity_log.title"}}
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      class="nested-activity-log-modal"
    >
      <:body>
        <DConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.smallActions.length}}
            <ul class="nested-activity-log-modal__list">
              {{#each this.smallActions as |sa|}}
                <NestedActivityLogItem
                  @action={{sa}}
                  @topicId={{@model.topic.id}}
                  @editPost={{this.editPost}}
                  @deletePost={{this.deletePost}}
                  @recoverPost={{this.recoverPost}}
                />
              {{/each}}
            </ul>
          {{else}}
            <p class="nested-activity-log-modal__empty">
              {{i18n "nested_replies.activity_log.empty"}}
            </p>
          {{/if}}
          {{#if this.hasMore}}
            <div class="nested-activity-log-modal__load-more">
              <DButton
                class="btn-default"
                @action={{this.loadMore}}
                @disabled={{this.loadingMore}}
                @isLoading={{this.loadingMore}}
                @label="nested_replies.activity_log.load_more"
              />
            </div>
          {{/if}}
        </DConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
