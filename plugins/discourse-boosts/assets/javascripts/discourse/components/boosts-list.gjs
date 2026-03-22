import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import createBoost from "../lib/create-boost";
import BoostBubble from "./boost-bubble";
import BoostInput from "./boost-input";

export default class BoostsList extends Component {
  @service currentUser;

  get boosts() {
    return this.args.post.boosts || [];
  }

  get canBoost() {
    return this.args.post.can_boost;
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  async handleDelete(boost, isOwnBoost) {
    const previousBoosts = this.boosts;
    const previousCanBoost = this.args.post.can_boost;
    this.args.post.boosts = this.boosts.filter((b) => b.id !== boost.id);

    if (isOwnBoost) {
      this.args.post.can_boost = true;
    }

    try {
      await ajax(`/discourse-boosts/boosts/${boost.id}`, { type: "DELETE" });
    } catch (e) {
      this.args.post.boosts = previousBoosts;
      this.args.post.can_boost = previousCanBoost;
      popupAjaxError(e);
    }
  }

  @action
  async addBoostWithRaw(raw) {
    this.dMenu?.close();
    await createBoost(this.args.post, raw, this.currentUser);
  }

  <template>
    {{#if this.boosts.length}}
      <div class="discourse-boosts">
        <div class="discourse-boosts__list">
          {{#each this.boosts as |boost|}}
            <BoostBubble @boost={{boost}} @onDelete={{this.handleDelete}} />
          {{/each}}

          {{#if this.canBoost}}
            <DMenu
              @identifier="discourse-boosts"
              @icon="rocket"
              @title={{i18n "discourse_boosts.boost_button_title"}}
              @modalForMobile={{false}}
              @onRegisterApi={{this.onRegisterApi}}
              @triggerClass="discourse-boosts__add-btn btn-flat"
              @triggers={{hash
                mobile=(array "click")
                desktop=(array "delayed-hover" "click")
              }}
            >
              <:content>
                <BoostInput
                  @post={{@post}}
                  @onSubmit={{this.addBoostWithRaw}}
                  @onClose={{this.dMenu.close}}
                />
              </:content>
            </DMenu>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
