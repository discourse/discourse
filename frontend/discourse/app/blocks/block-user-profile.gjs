import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { or } from "truth-helpers";
import { block } from "discourse/blocks";
import avatar from "discourse/helpers/avatar";
import dIcon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

@block("user-profile")
export default class BlockUserProfile extends Component {
  @service currentUser;

  @tracked banner;
  @tracked bio;
  @tracked website;
  @tracked websiteName;

  constructor() {
    super(...arguments);

    this.avatarSize = "huge";

    if (this.currentUser !== null) {
      ajax(`/u/${this.currentUser.username}.json`).then(({ user }) => {
        this.banner = user.profile_background_upload_url;
        this.bio = user.bio_excerpt;
        this.website = user.website;
        this.websiteName = user.website_name;
      });
    }
  }

  <template>
    {{#if this.currentUser}}

      <div
        class="block-user-profile__banner"
        style={{if
          this.banner
          (htmlSafe (concat "background-image: url('" this.banner "')"))
        }}
      />

      <div class="block-user-profile__avatar">
        {{avatar this.currentUser imageSize=this.avatarSize}}
      </div>

      <div class="block-user-profile__info">
        <div class="block-user-profile__name-wrapper">
          <span class="block-user-profile__name">
            {{or this.currentUser.name this.currentUser.username}}
          </span>
        </div>

        {{#if this.currentUser.name}}
          <a
            href="/u/{{this.currentUser.username}}"
            class="block-user-profile__username"
          >
            {{this.currentUser.username}}
          </a>
        {{/if}}

        <span class="block-user-profile__bio">
          {{htmlSafe this.bio}}
        </span>

        {{#if this.website}}
          <span class="block-user-profile__link">
            {{dIcon "globe"}}
            <a href={{this.website}}>
              {{this.websiteName}}
            </a>
          </span>
        {{/if}}

        <LinkTo
          @route="preferences.profile"
          @model={{this.currentUser}}
          class="block-user-profile__edit"
        >
          <span>{{i18n "js.edit"}}</span>
        </LinkTo>
      </div>

    {{/if}}
  </template>
}
