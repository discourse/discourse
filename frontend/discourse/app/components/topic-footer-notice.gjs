import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class TopicFooterNotice extends Component {
  @service siteSettings;

  <template>
    {{#if
      (and
        this.siteSettings.enable_topic_footer_notices
        @topic.footer_staff_notice
        (not @topic.isPrivateMessage)
      )
    }}
      <aside class="alert alert-info topic-footer-notice">
        {{@topic.footer_staff_notice}}
      </aside>
    {{/if}}
  </template>
}
