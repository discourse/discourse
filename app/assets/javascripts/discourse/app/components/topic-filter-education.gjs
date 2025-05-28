import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import basePath from "discourse/helpers/base-path";
import htmlSafe from "discourse/helpers/html-safe";
import { emojiUnescape } from "discourse/lib/text";

export default class TopicFilterEducation extends Component {
  @service currentUser;

  get educationText() {
    if (this.args.unreadFilter) {
      return "Nothing left unread...impressive!";
    } else if (this.args.newFilter) {
      if (this.currentUser.new_new_view_enabled) {
        return "NO NEW NEW";
      } else {
        return "Nothing new at the moment...check back soon!";
      }
    }
  }

  <template>
    <div class="topic-filter-education">
      <svg class="topic-filter-education__image">
      </svg>
      <div class="topic-filter-education__text">
        <p>{{this.educationText}}</p>
      </div>
      <div class="topic-filter-education__cta">
        <p>Check out what else is happening in this community.</p>

        <DButton
          @route="discovery.latest"
          @label="topic.browse_latest_topics"
        />

        <div class="topic-filter-education__preferences-hint">
          {{htmlSafe (emojiUnescape ":bulb:")}}
          You can view and change your new topic tracking settings in
          <a href="{{(basePath)}}/my/preferences/tracking">your preferences</a>.
        </div>
      </div>
    </div>
  </template>
}
