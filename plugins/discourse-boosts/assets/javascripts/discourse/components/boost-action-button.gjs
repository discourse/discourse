import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import BoostInput from "./boost-input";

export default class BoostActionButton extends Component {
  static shouldRender(args) {
    const post = args.post;
    return post.can_boost && !post.deleted && !post.boosts?.length;
  }

  @service currentUser;

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  async onSubmit(raw) {
    const previousBoosts = this.args.post.boosts || [];
    const optimisticBoost = {
      id: `pending-${Date.now()}`,
      raw,
      cooked: raw,
      user: {
        id: this.currentUser.id,
        username: this.currentUser.username,
        avatar_template: this.currentUser.avatar_template,
      },
      can_delete: true,
    };
    this.args.post.boosts = [...previousBoosts, optimisticBoost];
    this.dMenu?.close();

    try {
      const result = await ajax(
        `/discourse-boosts/posts/${this.args.post.id}/boosts`,
        { type: "POST", data: { raw } }
      );
      this.args.post.boosts = this.args.post.boosts.map((b) =>
        b.id === optimisticBoost.id ? result : b
      );
    } catch (e) {
      this.args.post.boosts = previousBoosts;
      popupAjaxError(e);
    }
  }

  <template>
    {{#if @shouldRender}}
      <DMenu
        @identifier="discourse-boosts"
        @icon="rocket"
        @title="discourse_boosts.boost_button_title"
        @modalForMobile={{false}}
        @onRegisterApi={{this.onRegisterApi}}
        @triggerClass="post-action-menu__boost boost btn-flat"
        ...attributes
      >
        <:content>
          <BoostInput
            @post={{@post}}
            @onSubmit={{this.onSubmit}}
            @onClose={{this.dMenu.close}}
          />
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
