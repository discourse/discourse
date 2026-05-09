import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class NestedRepliesExpandButton extends Component {
  get label() {
    return i18n("nested_replies.collapsed_replies", {
      count: this.args.replyCount,
    });
  }

  <template>
    <DButton
      class="nested-post__expand-replies btn-flat"
      ...attributes
      @action={{@onClick}}
      @icon="nested-circle-plus"
      @translatedLabel={{this.label}}
    />
  </template>
}
