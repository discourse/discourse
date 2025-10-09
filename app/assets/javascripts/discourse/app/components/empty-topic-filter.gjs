import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import EmptyState from "discourse/components/empty-state";
import SvgDocumentsCheckmark from "discourse/components/svg/documents-checkmark";
import basePath from "discourse/helpers/base-path";
import { i18n } from "discourse-i18n";

export default class EmptyTopicFilter extends Component {
  @service currentUser;

  get educationText() {
    if (this.args.unreadFilter) {
      return i18n("topics.none.education.unread");
    } else if (this.args.newFilter) {
      if (this.currentUser.new_new_view_enabled) {
        return i18n("topics.none.education.new_new");
      } else {
        return i18n("topics.none.education.new");
      }
    }
  }

  get ctaLabel() {
    if (this.currentUser.new_new_view_enabled) {
      if (this.args.newListSubset === "topics") {
        if (this.args.trackingCounts.newReplies > 0) {
          return i18n("topic.browse_new_replies");
        } else {
          return i18n("topic.browse_latest_topics");
        }
      }

      if (this.args.newListSubset === "replies") {
        if (this.args.trackingCounts.newTopics > 0) {
          return i18n("topic.browse_new_topics");
        } else {
          return i18n("topic.browse_latest_topics");
        }
      }
    }

    return i18n("topic.browse_latest_topics");
  }

  get ctaRoute() {
    if (this.currentUser.new_new_view_enabled) {
      if (this.args.newListSubset === undefined) {
        return "discovery.latest";
      }

      return;
    }

    return "discovery.latest";
  }

  get ctaAction() {
    if (this.args.newListSubset === "topics") {
      if (this.args.trackingCounts.newReplies > 0) {
        return () => this.args.changeNewListSubset("replies");
      }
    }

    if (this.args.newListSubset === "replies") {
      if (this.args.trackingCounts.newTopics > 0) {
        return () => this.args.changeNewListSubset("topics");
      }
    }
  }

  <template>
    <EmptyState
      @identifier="empty-topic-filter"
      @title={{this.educationText}}
      @ctaLabel={{this.ctaLabel}}
      @ctaRoute={{this.ctaRoute}}
      @ctaAction={{this.ctaAction}}
      @tipIcon="circle-info"
      @tipText={{htmlSafe
        (i18n
          "topics.none.education.topic_tracking_preferences" basePath=(basePath)
        )
      }}
      @svgContent={{SvgDocumentsCheckmark}}
    />
  </template>
}
