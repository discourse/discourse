import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import FlagModal from "discourse/components/modal/flag";
import DMenu from "discourse/float-kit/components/d-menu";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import BoostFlag from "../lib/boost-flag";
import createBoost from "../lib/create-boost";
import BoostInput from "./boost-input";

export default class BoostsList extends Component {
  @service currentUser;
  @service dialog;
  @service modal;

  @tracked selectedBoostId = null;

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
  toggleSelect(boostId) {
    if (this.selectedBoostId === boostId) {
      this.selectedBoostId = null;
    } else {
      this.selectedBoostId = boostId;
    }
  }

  @action
  async deleteBoost(boostId) {
    const boost = this.boosts.find((b) => b.id === boostId);
    const isOwnBoost = boost?.user?.id === this.currentUser?.id;

    if (!isOwnBoost) {
      this.dialog.yesNoConfirm({
        message: i18n("discourse_boosts.confirm_delete_boost"),
        didConfirm: () => this.#performDelete(boostId, boost, isOwnBoost),
      });
    } else {
      await this.#performDelete(boostId, boost, isOwnBoost);
    }
  }

  async #performDelete(boostId, boost, isOwnBoost) {
    const previousBoosts = this.boosts;
    const previousCanBoost = this.args.post.can_boost;
    this.args.post.boosts = this.boosts.filter((b) => b.id !== boostId);
    this.selectedBoostId = null;

    if (isOwnBoost) {
      this.args.post.can_boost = true;
    }

    try {
      await ajax(`/discourse-boosts/boosts/${boostId}`, { type: "DELETE" });
    } catch (e) {
      this.args.post.boosts = previousBoosts;
      this.args.post.can_boost = previousCanBoost;
      popupAjaxError(e);
    }
  }

  @action
  flagBoost(boost) {
    this.selectedBoostId = null;
    const flagTarget = new BoostFlag(getOwner(this));
    flagTarget.boostId = boost.id;
    flagTarget.availableFlags = boost.available_flags;

    this.modal.show(FlagModal, {
      model: {
        flagTarget,
        flagModel: { ...boost, user_id: boost.user.id },
        setHidden: () => {},
      },
    });
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
            <span
              class={{concatClass
                "discourse-boosts__bubble"
                (if (or boost.can_delete boost.can_flag) "--actionable")
                (if (eq this.selectedBoostId boost.id) "--selected")
              }}
            >
              <a data-user-card={{boost.user.username}}>{{boundAvatarTemplate
                  boost.user.avatar_template
                  "tiny"
                }}</a>
              {{#if (or boost.can_delete boost.can_flag)}}
                <button
                  type="button"
                  class="discourse-boosts__cooked btn-transparent"
                  {{on "click" (fn this.toggleSelect boost.id)}}
                >{{htmlSafe boost.cooked}}</button>
              {{else}}
                <span class="discourse-boosts__cooked">{{htmlSafe
                    boost.cooked
                  }}</span>
              {{/if}}
              {{#if (eq this.selectedBoostId boost.id)}}
                {{#if boost.can_flag}}
                  <button
                    type="button"
                    class="discourse-boosts__flag btn-transparent"
                    aria-label={{i18n "discourse_boosts.flag_boost"}}
                    {{on "click" (fn this.flagBoost boost)}}
                  >{{icon "flag"}}</button>
                {{/if}}
                {{#if boost.can_delete}}
                  <button
                    type="button"
                    class="discourse-boosts__delete btn-transparent --danger"
                    aria-label={{i18n "discourse_boosts.delete_boost"}}
                    {{on "click" (fn this.deleteBoost boost.id)}}
                  >{{icon "trash-can"}}</button>
                {{/if}}
              {{/if}}
            </span>
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
