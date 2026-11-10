/* eslint-disable prefer-const -- Preserve the original JavaScript emit for this types-only port. */
import { get } from "@ember/object";
import { trustHTML } from "@ember/template";
import { avatarImg, type AvatarSize } from "discourse/lib/avatar-utils";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

/** Returns the extra classes for a user's avatar. */
export type CustomAvatarHelper = (user: object) => string | string[];

/** Options for `renderAvatar`. */
export interface RenderAvatarOptions {
  /** The user property that holds the name. Defaults to `"name"`. */
  namePath?: string;

  /** The user property that holds the username. Defaults to `"username"`. */
  usernamePath?: string;

  /**
   * The user property that holds the avatar template. Defaults to
   * `"avatar_template"`.
   */
  avatarTemplatePath?: string;

  /** The image title, instead of the user's title or display name. */
  title?: string | null;

  /** Skips the user's title and description when picking a title. */
  ignoreTitle?: boolean;

  /** Leaves out the title. */
  hideTitle?: boolean;

  /** The avatar size. */
  imageSize?: AvatarSize;

  /** The value of the `loading` attribute. */
  loading?: string | null;

  /** Classes added after `avatar` when the user has no `extras`. */
  extraClasses?: string | null;

  /** The alt text, or `true` for the display name. Empty by default. */
  alt?: string | true | null;
}

let _customAvatarHelpers: CustomAvatarHelper[] | undefined;

/**
 * Registers a function that adds classes to users' avatars.
 *
 * @param fn - Returns the extra classes for a user.
 */
export function registerCustomAvatarHelper(fn: CustomAvatarHelper) {
  _customAvatarHelpers = _customAvatarHelpers || [];
  _customAvatarHelpers.push(fn);
}

/**
 * Sets `extraClasses` to the registered classes for a user, if there are any.
 *
 * @param u - The user.
 * @param args - The avatar options. They are changed in place.
 * @returns The avatar options.
 */
export function addExtraUserClasses<T extends object>(
  u: object,
  args: T
): T & { extraClasses?: string } {
  let extraClasses = classesForUser(u).join(" ");
  if (extraClasses && extraClasses.length) {
    (args as T & { extraClasses?: string }).extraClasses = extraClasses;
  }
  return args;
}

/**
 * Collects the registered classes for a user's avatar.
 *
 * @param u - The user.
 * @returns The classes.
 */
export function classesForUser(u: object): string[] {
  let result: string[] = [];
  if (_customAvatarHelpers) {
    for (let i = 0; i < _customAvatarHelpers.length; i++) {
      result = result.concat(_customAvatarHelpers[i](u));
    }
  }
  return result;
}

/**
 * Renders a user's avatar image.
 *
 * @param user - The user.
 * @param options - The options.
 * @returns The image HTML, or `""` without a user, a username or an avatar
 *   template.
 */
export function renderAvatar(
  user: object | null | undefined,
  options?: RenderAvatarOptions | null
): string {
  options = options || {};

  if (user) {
    const name = get(user, options.namePath || "name") as
      | string
      | null
      | undefined;
    const username = get(user, options.usernamePath || "username") as
      | string
      | null
      | undefined;
    const avatarTemplate = get(
      user,
      options.avatarTemplatePath || "avatar_template"
    ) as string | null | undefined;

    if (!username || !avatarTemplate) {
      return "";
    }

    let displayName = prioritizeNameInUx(name)
      ? name
      : formatUsername(username);

    let title = options.title;
    if (!title && !options.ignoreTitle) {
      // first try to get a title
      title = get(user, "title") as string | null | undefined;
      // if there was no title provided
      if (!title) {
        // try to retrieve a description
        const description = get(user, "description") as
          | string
          | null
          | undefined;
        // if a description has been provided
        if (description && description.length > 0) {
          // prepend the username before the description
          title = i18n("user.avatar.name_and_description", {
            name: displayName,
            description,
          });
        }
      }
    }

    return avatarImg({
      // Callers pass a size; `avatarImg` cannot render a missing one.
      size: options.imageSize as AvatarSize,
      extraClasses:
        (get(user, "extras") as string | null | undefined) ||
        options.extraClasses,
      loading: options.loading,
      title: options.hideTitle ? null : title || displayName,
      // `alt: true` names the person rather than making the caller repeat the
      // display-name logic above; a string sets it verbatim.
      alt: options.alt === true ? displayName : options.alt,
      avatarTemplate,
    });
  } else {
    return "";
  }
}

/**
 * Renders a user's avatar image.
 *
 * @param user - The user.
 * @param params - The options for `renderAvatar`.
 * @returns The image.
 */
export default function dAvatar(
  this: unknown,
  user: object | null | undefined,
  params?: RenderAvatarOptions | null
) {
  return trustHTML(renderAvatar.call(this, user, params));
}
