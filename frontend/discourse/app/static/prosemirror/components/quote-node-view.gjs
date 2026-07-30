import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";

const avatarTemplates = new Map();

function lookupAvatarTemplate(username) {
  const key = username.toLowerCase();

  if (!avatarTemplates.has(key)) {
    avatarTemplates.set(
      key,
      ajax(userPath(`${encodeURIComponent(username)}/card.json`))
        .then(({ user }) => user?.avatar_template)
        .catch(() => null)
    );
  }

  return avatarTemplates.get(key);
}

export default class QuoteNodeView extends Component {
  @tracked avatarTemplate;

  constructor() {
    super(...arguments);
    this.loadAvatar();
  }

  get username() {
    return this.args.node.attrs.username;
  }

  get displayName() {
    return this.args.node.attrs.displayName || this.username;
  }

  @action
  async loadAvatar() {
    const { username } = this;
    const avatarTemplate = await lookupAvatarTemplate(username);

    // the quoted user may have changed while this was in flight
    if (username === this.username && !this.isDestroying && !this.isDestroyed) {
      this.avatarTemplate = avatarTemplate;
    }
  }

  <template>
    {{~! strip whitespace ~}}<div
      class="title"
      {{didUpdate this.loadAvatar this.username}}
    >
      {{~#if this.avatarTemplate~}}
        {{dBoundAvatarTemplate this.avatarTemplate "tiny"}}
      {{~/if~}}
      {{~this.displayName}}:</div>{{~yield~}}{{~! strip whitespace ~}}
  </template>
}
