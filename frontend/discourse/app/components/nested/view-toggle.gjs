import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";

export default class NestedViewToggle extends Component {
  @service currentUser;

  get showToggle() {
    return this.currentUser && this.args.topic.is_nested_view;
  }

  @action
  async toggle() {
    const topic = this.args.topic;
    const preferFlat = !this.currentUser.user_option.prefer_flat_replies;

    this.currentUser.set("user_option.prefer_flat_replies", preferFlat);

    try {
      await this.currentUser.save(["prefer_flat_replies"]);
    } catch (e) {
      this.currentUser.set("user_option.prefer_flat_replies", !preferFlat);
      popupAjaxError(e);
      return;
    }

    DiscourseURL.routeTo(`/t/${topic.slug}/${topic.id}`);
  }

  <template>
    {{#if this.showToggle}}
      {{#if @topic.rendersNested}}
        <DButton
          class="btn-flat nested-view-toggle --to-flat"
          @action={{this.toggle}}
          @icon="bars"
          @label="nested_replies.flat_view"
          @title="nested_replies.flat_view_title"
        />
      {{else}}
        <DButton
          class="btn-flat nested-view-toggle --to-nested"
          @action={{this.toggle}}
          @icon="bars-staggered"
          @label="nested_replies.nested_view"
          @title="nested_replies.nested_view_title"
        />
      {{/if}}
    {{/if}}
  </template>
}
