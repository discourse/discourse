import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq, gt } from "discourse/truth-helpers";
import BoostInput from "./boost-input";

export default class BoostsList extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked selectedBoostId = null;

  get boosts() {
    return this.args.post.boosts || [];
  }

  get canBoost() {
    return this.args.post.can_boost;
  }

  get remainingBoosts() {
    if (!this.currentUser) {
      return 0;
    }
    const userBoostCount = this.boosts.filter(
      (b) => b.user.id === this.currentUser.id
    ).length;
    return (
      this.siteSettings.discourse_boosts_max_per_user_per_post - userBoostCount
    );
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  toggleDelete(boostId) {
    if (this.selectedBoostId === boostId) {
      this.selectedBoostId = null;
    } else {
      this.selectedBoostId = boostId;
    }
  }

  @action
  async deleteBoost(boostId) {
    const previousBoosts = this.boosts;
    this.args.post.boosts = this.boosts.filter((b) => b.id !== boostId);
    this.selectedBoostId = null;

    try {
      await ajax(`/discourse-boosts/boosts/${boostId}`, { type: "DELETE" });
    } catch (e) {
      this.args.post.boosts = previousBoosts;
      popupAjaxError(e);
    }
  }

  @action
  async addBoostWithRaw(raw) {
    const previousBoosts = this.boosts;
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
    {{#if this.boosts.length}}
      <div class="discourse-boosts">
        <div class="discourse-boosts__list">
          {{#each this.boosts as |boost|}}
            <span
              class={{concatClass
                "discourse-boosts__bubble"
                (if boost.can_delete "discourse-boosts__bubble--deletable")
                (if
                  (eq this.selectedBoostId boost.id)
                  "discourse-boosts__bubble--selected"
                )
              }}
            >
              <a data-user-card={{boost.user.username}}>{{boundAvatarTemplate
                  boost.user.avatar_template
                  "tiny"
                }}</a>
              {{#if boost.can_delete}}
                <button
                  type="button"
                  class="discourse-boosts__cooked btn-transparent"
                  {{on "click" (fn this.toggleDelete boost.id)}}
                >{{htmlSafe boost.cooked}}</button>
              {{else}}
                <span class="discourse-boosts__cooked">{{htmlSafe
                    boost.cooked
                  }}</span>
              {{/if}}
              {{#if (eq this.selectedBoostId boost.id)}}
                <button
                  type="button"
                  class="discourse-boosts__delete btn-transparent"
                  {{on "click" (fn this.deleteBoost boost.id)}}
                >{{icon "trash-can"}}</button>
              {{/if}}
            </span>
          {{/each}}

          {{#if this.canBoost}}
            {{#if (gt this.remainingBoosts 0)}}
              <DMenu
                @identifier="discourse-boosts"
                @icon="rocket"
                @title="discourse_boosts.boost_button_title"
                @modalForMobile={{false}}
                @onRegisterApi={{this.onRegisterApi}}
                @triggerClass="discourse-boosts__add-btn btn-flat"
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
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
