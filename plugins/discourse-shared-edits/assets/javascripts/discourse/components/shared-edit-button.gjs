import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

export default class SharedEditButton extends Component {
  static shouldRender(args) {
    return args.post.can_edit;
  }

  @service appEvents;
  @service site;

  get showLabel() {
    return this.args.showLabel ?? this.site.desktopView;
  }

  @action
  sharedEdit() {
    // eslint-disable-next-line no-console
    console.log("[Shared Edit Button] Button clicked", {
      postId: this.args.post?.id,
      sharedEditsEnabled: this.args.post?.shared_edits_enabled,
      canEdit: this.args.post?.can_edit,
    });
    this.appEvents.trigger("shared-edit-on-post", this.args.post);
  }

  <template>
    <DButton
      class={{concatClass
        "post-action-menu__shared-edit"
        "shared-edit"
        "create fade-out"
      }}
      ...attributes
      @action={{this.sharedEdit}}
      @icon="far-pen-to-square"
      @label={{if this.showLabel "post.controls.edit_action"}}
      @title="shared_edits.button_title"
    />
  </template>
}
