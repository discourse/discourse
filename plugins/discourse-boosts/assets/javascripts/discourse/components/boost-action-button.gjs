import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { i18n } from "discourse-i18n";
import createBoost from "../lib/create-boost";
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
    this.dMenu?.close();
    await createBoost(this.args.post, raw, this.currentUser);
  }

  <template>
    {{#if @shouldRender}}
      <DMenu
        @identifier="discourse-boosts"
        @icon="rocket"
        @title={{i18n "discourse_boosts.boost_button_title"}}
        @modalForMobile={{false}}
        @onRegisterApi={{this.onRegisterApi}}
        @triggerClass="post-action-menu__boost boost btn-flat"
        @triggers={{hash
          mobile=(array "click")
          desktop=(array "delayed-hover" "click")
        }}
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
