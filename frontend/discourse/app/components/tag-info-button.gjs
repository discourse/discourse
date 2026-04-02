import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class TagInfoButton extends Component {
  @service router;

  get canEditTags() {
    return this.args.currentUser?.canEditTags;
  }

  @action
  handleClick() {
    this.router.transitionTo(
      "tag.edit.tab",
      this.args.tag.slug,
      this.args.tag.id,
      "general"
    );
  }

  <template>
    {{#if this.canEditTags}}
      <DButton
        @icon="wrench"
        @ariaLabel="tagging.edit"
        @title="tagging.edit"
        @action={{this.handleClick}}
        id="show-tag-info"
        class="btn-default"
      />
    {{/if}}
  </template>
}
