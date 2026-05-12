// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
/** @type {import("discourse/ui-kit/d-user-link.gjs")} */
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

// TODO (saquetim) the pattern <a>{{avatar ...}}</a> is used a lot. Should we replace it with this component to ensure consistency???

/**
 * The canonical "avatar that links to a user profile" combination. Wraps
 * `DUserLink` (which produces the `<a>` and resolves the URL) around the
 * `dAvatar` helper (which renders the `<img>`). Use this anywhere you need a
 * clickable avatar so URL resolution, anon-user hiding, and the `data-user-card`
 * popover hook stay consistent.
 *
 * Avatars are hidden from assistive tech by default because they are almost
 * always paired with a visible username and would be a redundant announcement.
 * Set `@ariaLabel` or `@ariaHidden={{false}}` when the avatar stands alone.
 *
 * @example
 * <DUserAvatar @user={{this.post.user}} @size={{45}} />
 */

/**
 * @typedef DUserAvatarSignature
 *
 * @property {object} Args
 *
 * @property {object} Args.user The user object. Must expose `username` and (optionally) `path` and avatar fields consumed by the `dAvatar` helper.
 * @property {boolean} [Args.ariaHidden] When `true` (the default), the link is hidden from screen readers. Pass `false` when the avatar carries information not duplicated by an adjacent username.
 * @property {string} [Args.ariaLabel] Pre-translated `aria-label` for the link. Overrides the default `"{username}'s profile"` text. Implies the avatar is *not* hidden.
 * @property {string} [Args.href] Override URL. Defaults to `@user.path` or the canonical user-profile URL derived from `@user.username`.
 * @property {string} [Args.avatarClasses] Extra classes joined onto the `<img>` rendered by `dAvatar`.
 * @property {number} [Args.size] Image dimensions in CSS pixels (square).
 * @property {boolean} [Args.hideTitle] When `true`, the `<img title>` tooltip is suppressed.
 * @property {boolean} [Args.lazy] When `true`, the avatar `<img>` is rendered with `loading="lazy"`.
 *
 * @property {HTMLAnchorElement} Element The `<a>` element from `DUserLink`.
 *
 * @property {object} Blocks
 * @property {[]} Blocks.default Not used.
 */

/** @extends {Component<DUserAvatarSignature>} */
export default class DUserAvatar extends Component {
  @service currentUser;
  @service siteSettings;

  get ariaHidden() {
    if (this.args.ariaHidden !== null) {
      return this.args.ariaHidden;
    }

    if (this.args.ariaLabel) {
      return false;
    }

    // often avatars are paired with usernames, making them redundant for screen readers so we hide the avatar from
    // screen readers by default
    return this.args.ariaHidden ?? true;
  }

  get hideFromAnonUser() {
    return (
      this.siteSettings.hide_user_profiles_from_public && !this.currentUser
    );
  }

  <template>
    <DUserLink
      ...attributes
      @ariaHidden={{@ariaHidden}}
      @ariaLabel={{@ariaLabel}}
      @href={{@href}}
      @user={{@user}}
    >
      {{dAvatar
        @user
        extraClasses=(dConcatClass
          @avatarClasses (if this.hideFromAnonUser "non-clickable")
        )
        imageSize=@size
        hideTitle=@hideTitle
        loading=(if @lazy "lazy")
      }}
    </DUserLink>
  </template>
}
