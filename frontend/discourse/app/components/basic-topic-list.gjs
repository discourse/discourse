/* eslint-disable ember/no-classic-components, ember/no-observers, ember/require-tagless-components */
import Component from "@ember/component";
import { computed, set } from "@ember/object";
import { service } from "@ember/service";
import { observes } from "@ember-decorators/object";
import List from "discourse/components/topic-list/list";
import domUtils from "discourse/lib/dom-utils";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import { i18n } from "discourse-i18n";

export default class BasicTopicList extends Component {
  @service site;

  init() {
    super.init(...arguments);
    const topicList = this.topicList;
    if (topicList) {
      this._initFromTopicList(topicList);
    }
  }

  @computed("topicList.loadingMore")
  get loadingMore() {
    return this.topicList?.loadingMore;
  }

  set loadingMore(value) {
    set(this, "topicList.loadingMore", value);
  }

  @computed("loaded")
  get loading() {
    return !this.loaded;
  }

  @computed("topicList.loaded")
  get loaded() {
    let topicList = this.topicList;
    if (topicList) {
      return topicList.get("loaded");
    } else {
      return true;
    }
  }

  @observes("topicList.[]")
  _topicListChanged() {
    this._initFromTopicList(this.topicList);
  }

  _initFromTopicList(topicList) {
    if (topicList !== null) {
      this.set("topics", topicList.get("topics"));
      this.rerender();
    }
  }

  @computed("topics")
  get showUnreadIndicator() {
    return this.topics.some(
      (topic) => typeof topic.unread_by_group_member !== "undefined"
    );
  }

  click(e) {
    // Mobile basic-topic-list doesn't use the `topic-list-item` view so
    // the event for the topic entrance is never wired up.
    if (this.site.desktopView) {
      return;
    }

    let target = e.target;
    if (target.closest(".posts-map")) {
      const topicId = target.closest("tr")?.getAttribute("data-topic-id");
      if (topicId) {
        if (target.tagName !== "A") {
          const link = target.querySelector("a") || target.closest("a");
          if (link) {
            target = link;
          } else {
            return false;
          }
        }

        const topic = this.topics.find(
          (value) => value.id === parseInt(topicId, 10)
        );
        this.appEvents.trigger("topic-entrance:show", {
          topic,
          position: domUtils.offset(target),
        });
      }
      return false;
    }
  }

  <template>
    <DConditionalLoadingSpinner @condition={{this.loading}}>
      {{#if this.topics}}
        <List
          @showPosters={{this.showPosters}}
          @hideCategory={{this.hideCategory}}
          @topics={{this.topics}}
          @expandExcerpts={{this.expandExcerpts}}
          @bulkSelectHelper={{this.bulkSelectHelper}}
          @canBulkSelect={{this.canBulkSelect}}
          @tagsForUser={{this.tagsForUser}}
          @changeSort={{this.changeSort}}
          @order={{this.order}}
          @ascending={{this.ascending}}
          @focusLastVisitedTopic={{this.focusLastVisitedTopic}}
          @listContext={{this.listContext}}
        />
      {{else}}
        {{#unless this.loadingMore}}
          <div class="alert alert-info">
            {{i18n "choose_topic.none_found"}}
          </div>
        {{/unless}}
      {{/if}}
    </DConditionalLoadingSpinner>
  </template>
}
