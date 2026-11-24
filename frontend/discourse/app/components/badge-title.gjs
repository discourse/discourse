import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DSelectBadge from "discourse/ui-kit/select/recipes/badges/d-select-badge";
import { i18n } from "discourse-i18n";

export default class BadgeTitle extends Component {
  @service currentUser;
  @service dialog;
  @service siteSettings;

  @tracked _selectedUserBadgeId;
  @tracked _isSaved = false;
  @tracked _isSaving = false;

  constructor() {
    super(...arguments);

    const badge = this._findBadgeByTitle(
      this.args.selectableUserBadges,
      this.currentUser.title
    );
    this._selectedUserBadgeId = badge?.id || 0;
  }

  get selectedTitleBadgeId() {
    return (
      this._findBadgeById(this.#userBadges, this._selectedUserBadgeId)?.badge
        .id ?? null
    );
  }

  /** The badges behind the user badges, without the page's placeholder for none. */
  get titleBadges() {
    return this.#userBadges.map((userBadge) => userBadge.badge);
  }

  get #userBadges() {
    return (this.args.selectableUserBadges || []).filter((ub) => ub.id !== 0);
  }

  @action
  saveBadgeTitle() {
    this._isSaved = false;
    this._isSaving = true;

    const selectedUserBadge = this._findBadgeById(
      this.#userBadges,
      this._selectedUserBadgeId
    );

    return ajax(`${this.currentUser.path}/preferences/badge_title`, {
      type: "PUT",
      data: { user_badge_id: selectedUserBadge?.id || 0 },
    })
      .then(
        () => {
          this._isSaved = true;
          this.currentUser.set("title", selectedUserBadge?.badge?.name || "");
        },
        () => {
          this.dialog.alert(i18n("generic_error"));
        }
      )
      .finally(() => (this._isSaving = false));
  }

  @action
  selectTitleBadge(badgeId) {
    this._selectedUserBadgeId =
      this.#userBadges.find((ub) => ub.badge.id === badgeId)?.id ?? 0;
  }

  _findBadgeById(badges, id) {
    return (badges || []).find((b) => b.id === id);
  }

  _findBadgeByTitle(badges, title) {
    return (badges || []).find((b) => b.badge.name === title);
  }

  <template>
    <div class="badge-title">
      <form class="form-horizontal">

        <h3 id="badge-title-heading">{{i18n
            "badges.select_badge_for_title"
          }}</h3>

        <div class="control-group">
          <div class="controls">
            {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
            {{#if this.siteSettings.enable_new_select_controls}}
              <DSelectBadge
                @ariaLabelledBy="badge-title-heading"
                @identifier="badge-title"
                @noneOption={{true}}
                @onChange={{this.selectTitleBadge}}
                @options={{this.titleBadges}}
                @texts={{hash noneLabel=(i18n "badges.none")}}
                @value={{this.selectedTitleBadgeId}}
              />
            {{else}}
              <ComboBox
                @content={{@selectableUserBadges}}
                @nameProperty="badge.name"
                @onChange={{fn (mut this._selectedUserBadgeId)}}
                @value={{this._selectedUserBadgeId}}
              />
            {{/if}}
          </div>
        </div>

        <div class="control-group">
          <div class="controls">
            <DButton
              class="btn-primary"
              @action={{this.saveBadgeTitle}}
              @disabled={{this._isSaving}}
              @label={{if this._isSaving "saving" "save"}}
            />
            {{#if @closeAction}}
              <DButton
                class="btn-default close-btn"
                @action={{@closeAction}}
                @label="close"
              />
            {{/if}}
            {{#if this._isSaved}}
              <span class="badge-title__saved" role="status">{{i18n
                  "saved"
                }}</span>
            {{/if}}
          </div>
        </div>
      </form>
    </div>
  </template>
}
