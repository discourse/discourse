import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";

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
}
<DModal
  @title={{i18n "user.auth_tokens.was_this_you"}}
  @closeModal={{@closeModal}}
>
  <:body>
    <div>
      <p>{{i18n "user.auth_tokens.was_this_you_description"}}</p>
      <p>{{html-safe (i18n "user.second_factor.extended_description")}}</p>
    </div>
    <div>
      <h3>{{i18n "user.auth_tokens.details"}}</h3>
      <ul>
        <li>{{d-icon "far-clock"}} {{format-date @model.seen_at}}</li>
        <li>{{d-icon "location-dot"}} {{@model.location}}</li>
        <li>{{d-icon @model.icon}}
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
          <a href {{on "click" this.toggleExpanded}} {{auto-focus}}>
            {{d-icon (if this.expanded "caret-up" "caret-down")}}
          </a>
        </h3>
        {{#if this.expanded}}
          <blockquote>{{html-safe this.latestPost.cooked}}</blockquote>
        {{else}}
          <blockquote>{{html-safe this.latestPost.excerpt}}</blockquote>
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