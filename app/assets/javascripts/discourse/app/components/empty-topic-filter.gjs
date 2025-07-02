import Component from "@glimmer/component";
import { service } from "@ember/service";
import EmptyState from "discourse/components/empty-state";
import SvgDocumentsCheckmark from "discourse/components/svg/documents-checkmark";
import basePath from "discourse/helpers/base-path";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

export default class EmptyTopicFilter extends Component {
  @service currentUser;

  get educationText() {
    if (this.args.unreadFilter) {
      return "topics.none.education.unread";
    } else if (this.args.newFilter) {
      if (this.currentUser.new_new_view_enabled) {
        return "topics.none.education.new_new";
      } else {
        return "topics.none.education.new";
      }
    }
  }

  <template>
    <EmptyState
      @identifier="empty-topic-filter"
      @title={{this.educationText}}
      @ctaLabel="topic.browse_latest_topics"
      @ctaRoute="discovery.latest"
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
