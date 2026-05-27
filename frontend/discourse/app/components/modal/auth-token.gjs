import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

export default class AuthTokenComponent extends Component {
  @service currentUser;

  @tracked expanded = false;
  @tracked latestPost = null;

  constructor() {
    super(...arguments);
    this.fetchActivity();
  }

  @action
  async fetchActivity() {
    const posts = await ajax(
      userPath(`${this.currentUser.username_lower}/activity.json`)
    );
    if (posts.length > 0) {
      this.latestPost = posts[0];
    }
  }

  @action
  toggleExpanded(event) {
    event?.preventDefault();
    this.expanded = !this.expanded;
  }

  <template>
    <DModal
      @title={{i18n "user.auth_tokens.was_this_you"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div>
          <p>{{i18n "user.auth_tokens.was_this_you_description"}}</p>
          <p>{{trustHTML (i18n "user.second_factor.extended_description")}}</p>
        </div>
        <div>
          <h3>{{i18n "user.auth_tokens.details"}}</h3>
          <ul>
            <li>{{dIcon "far-clock"}} {{dFormatDate @model.seen_at}}</li>
            <li>{{dIcon "location-dot"}} {{@model.location}}</li>
            <li>{{dIcon @model.icon}}
              {{i18n
                "user.auth_tokens.browser_and_device"
                browser=@model.browser
                device=@model.device
              }}</li>
          </ul>
        </div>

        {{#if this.latestPost}}
          <div>
            <h3>
              {{i18n "user.auth_tokens.latest_post"}}
              {{! when this.fetchActivity is called, the modal focus is reset }}
              {{! allowing you to tab behind the modal, so we need to refocus }}
              <a href {{on "click" this.toggleExpanded}} {{dAutoFocus}}>
                {{dIcon (if this.expanded "angle-up" "angle-down")}}
              </a>
            </h3>
            {{#if this.expanded}}
              <blockquote>{{trustHTML this.latestPost.cooked}}</blockquote>
            {{else}}
              <blockquote>{{trustHTML this.latestPost.excerpt}}</blockquote>
            {{/if}}
          </div>
        {{/if}}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{@closeModal}}
          @icon="lock"
          @label="user.auth_tokens.secure_account"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
