/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { alias, not } from "@ember/object/computed";
import { service } from "@ember/service";
import { observes } from "@ember-decorators/object";
import $ from "jquery";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import List from "discourse/components/topic-list/list";
import discourseComputed, { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class BasicTopicList extends Component {
  @service site;

  @alias("topicList.loadingMore") loadingMore;

  @not("loaded") loading;

  init() {
    super.init(...arguments);
    const topicList = this.topicList;
    if (topicList) {
      this._initFromTopicList(topicList);
    }
  }

  @discourseComputed("topicList.loaded")
  loaded() {
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

  didInsertElement() {
    super.didInsertElement(...arguments);

    this.topics.forEach((topic) => {
      if (typeof topic.unread_by_group_member !== "undefined") {
        this.messageBus.subscribe(
          `/private-messages/unread-indicator/${topic.id}`,
          this.onMessage
        );
      }
    });
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this.messageBus.unsubscribe(
      "/private-messages/unread-indicator/*",
      this.onMessage
    );
  }

  @bind
  onMessage(data) {
    const nodeClassList = document.querySelector(
      `.indicator-topic-${data.topic_id}`
    ).classList;

    nodeClassList.toggle("read", !data.show_indicator);
  }

  @discourseComputed("topics")
  showUnreadIndicator(topics) {
    return topics.some(
      (topic) => typeof topic.unread_by_group_member !== "undefined"
    );
  }

  click(e) {
    // Mobile basic-topic-list doesn't use the `topic-list-item` view so
    // the event for the topic entrance is never wired up.
    if (this.site.desktopView) {
      return;
    }

    let target = $(e.target);
    if (target.closest(".posts-map").length) {
      const topicId = target.closest("tr").attr("data-topic-id");
      if (topicId) {
        if (target.prop("tagName") !== "A") {
          let targetLinks = target.find("a");
          if (targetLinks.length) {
            target = targetLinks;
          } else {
            targetLinks = target.closest("a");
            if (targetLinks.length) {
              target = targetLinks;
            } else {
              return false;
            }
          }
        }

        const topic = this.topics.find(
          (value) => value.id === parseInt(topicId, 10)
        );
        this.appEvents.trigger("topic-entrance:show", {
          topic,
          position: target.offset(),
        });
      }
      return false;
    }
  }

  <template>
    <ConditionalLoadingSpinner @condition={{this.loading}}>
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
        />
      {{else}}
        {{#unless this.loadingMore}}
          <div class="alert alert-info">
            {{i18n "choose_topic.none_found"}}
          </div>
        {{/unless}}
      {{/if}}
    </ConditionalLoadingSpinner>
  </template>
}
