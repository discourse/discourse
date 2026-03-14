import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import FlagModal from "discourse/components/modal/flag";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import BoostFlag from "../lib/boost-flag";

export default class BoostBubble extends Component {
  @service currentUser;
  @service dialog;
  @service modal;

  @tracked expanded = false;

  get boost() {
    return this.args.boost;
  }

  get canInteract() {
    if (!this.currentUser) {
      return false;
    }
    if (this.boost.can_delete === undefined) {
      return true;
    }
    return this.boost.can_delete || this.boost.can_flag;
  }

  async #ensurePermissions() {
    if (this.boost.can_delete !== undefined) {
      return;
    }
    const data = await ajax(`/discourse-boosts/boosts/${this.boost.id}`);
    Object.assign(this.boost, {
      can_flag: data.can_flag,
      can_delete: data.can_delete,
      available_flags: data.available_flags,
      user_flag_status: data.user_flag_status,
    });
  }

  @action
  async toggle() {
    if (this.expanded) {
      this.expanded = false;
      return;
    }

    await this.#ensurePermissions();
    this.expanded = true;
  }

  @action
  async deleteBoost() {
    const boost = this.boost;
    const isOwnBoost = boost.user?.id === this.currentUser?.id;

    if (!isOwnBoost) {
      this.dialog.yesNoConfirm({
        message: i18n("discourse_boosts.confirm_delete_boost"),
        didConfirm: () => this.#performDelete(isOwnBoost),
      });
    } else {
      await this.#performDelete(isOwnBoost);
    }
  }

  async #performDelete(isOwnBoost) {
    this.expanded = false;
    this.args.onDelete?.(this.boost, isOwnBoost);
  }

  @action
  flagBoost() {
    this.expanded = false;
    const boost = this.boost;
    const flagTarget = new BoostFlag(getOwner(this));
    flagTarget.boostId = boost.id;
    flagTarget.availableFlags = boost.available_flags;

    this.modal.show(FlagModal, {
      model: {
        flagTarget,
        flagModel: {
          ...boost,
          user_id: boost.user.id,
          username: boost.user.username,
        },
        setHidden: () => {},
      },
    });
  }

  <template>
    <span
      class={{concatClass
        "discourse-boosts__bubble"
        (if this.canInteract "--actionable")
        (if this.expanded "--selected")
      }}
    >
      <a data-user-card={{this.boost.user.username}}>{{boundAvatarTemplate
          this.boost.user.avatar_template
          "tiny"
        }}</a>
      {{#if this.canInteract}}
        <button
          type="button"
          class="discourse-boosts__cooked btn-transparent"
          {{on "click" this.toggle}}
        >{{htmlSafe this.boost.cooked}}</button>
      {{else}}
        <span class="discourse-boosts__cooked">{{htmlSafe
            this.boost.cooked
          }}</span>
      {{/if}}
      {{#if this.expanded}}
        {{#if this.boost.can_flag}}
          <button
            type="button"
            class="discourse-boosts__flag btn-transparent"
            aria-label={{i18n "discourse_boosts.flag_boost"}}
            {{on "click" (fn this.flagBoost this.boost)}}
          >{{icon "flag"}}</button>
        {{/if}}
        {{#if this.boost.can_delete}}
          <button
            type="button"
            class="discourse-boosts__delete btn-transparent --danger"
            aria-label={{i18n "discourse_boosts.delete_boost"}}
            {{on "click" (fn this.deleteBoost this.boost)}}
          >{{icon "trash-can"}}</button>
        {{/if}}
      {{/if}}
    </span>
  </template>
}
