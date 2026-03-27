import Component from "@glimmer/component";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class NestedViewLink extends Component {
  static shouldRender(args, context) {
    return (
      context.siteSettings.nested_replies_enabled &&
      args.topic?.is_nested_view &&
      context.currentUser?.can_toggle_nested_mode
    );
  }

  get nestedUrl() {
    const topic = this.args.outletArgs.topic;
    return getURL(`/n/${topic.slug}/${topic.id}`);
  }

  <template>
    <a href={{this.nestedUrl}} class="nested-view-link">{{i18n
        "nested_replies.view_as_nested"
      }}</a>
  </template>
}
