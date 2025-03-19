import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

@tagName("")
export default class BadgeTitle extends Component {
  @service dialog;

  selectableUserBadges = null;
  _selectedUserBadgeId = null;
  _isSaved = false;
  _isSaving = false;

  init() {
    super.init(...arguments);

    const badge = this._findBadgeByTitle(
      this.selectableUserBadges,
      this.currentUser.title
    );
    this.set("_selectedUserBadgeId", badge?.id || 0);
  }

  @action
  saveBadgeTitle() {
    this.setProperties({ _isSaved: false, _isSaving: true });

    const selectedUserBadge = this._findBadgeById(
      this.selectableUserBadges,
      this._selectedUserBadgeId
    );

    return ajax(`${this.currentUser.path}/preferences/badge_title`, {
      type: "PUT",
      data: { user_badge_id: selectedUserBadge?.id || 0 },
    })
      .then(
        () => {
          this.set("_isSaved", true);
          this.currentUser.set("title", selectedUserBadge?.badge?.name || "");
        },
        () => {
          this.dialog.alert(i18n("generic_error"));
        }
      )
      .finally(() => this.set("_isSaving", false));
  }

  _findBadgeById(badges, id) {
    return (badges || []).findBy("id", id);
  }

  _findBadgeByTitle(badges, title) {
    return (badges || []).findBy("badge.name", title);
  }

  <template>
    <div class="badge-title">
      <form class="form-horizontal">

        <h3>{{i18n "badges.select_badge_for_title"}}</h3>

        <div class="control-group">
          <div class="controls">
            <ComboBox
              @value={{this._selectedUserBadgeId}}
              @nameProperty="badge.name"
              @content={{this.selectableUserBadges}}
              @onChange={{fn (mut this._selectedUserBadgeId)}}
            />
          </div>
        </div>

        <div class="control-group">
          <div class="controls">
            <DButton
              @action={{this.saveBadgeTitle}}
              @disabled={{this._isSaving}}
              @label={{if this._isSaving "saving" "save"}}
              class="btn-primary"
            />
            {{#if this.closeAction}}
              <DButton
                @action={{this.closeAction}}
                @label="close"
                class="btn-default close-btn"
              />
            {{/if}}
            {{#if this._isSaved}}
              <span role="status" class="badge-title__saved">{{i18n
                  "saved"
                }}</span>
            {{/if}}
          </div>
        </div>
      </form>
    </div>
  </template>
}
