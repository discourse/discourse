import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { avatarImg, type AvatarSize } from "discourse/lib/avatar-utils";
import { addExtraUserClasses } from "discourse/ui-kit/helpers/d-user-avatar";

/**
 * Renders a user's avatar, or a placeholder without a user.
 *
 * @param user - The user.
 * @param size - The avatar size.
 * @returns The avatar image or the placeholder.
 */
export default function dBoundAvatar(
  user: { avatar_template?: string | null } | null | undefined,
  size: AvatarSize
) {
  if (isEmpty(user)) {
    return trustHTML("<div class='avatar-placeholder'></div>");
  }

  return trustHTML(
    avatarImg(
      // `isEmpty` is true for a missing user.
      addExtraUserClasses(user!, {
        size,
        avatarTemplate: user!.avatar_template,
      })
    )
  );
}
