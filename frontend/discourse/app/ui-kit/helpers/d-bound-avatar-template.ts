import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import type { AvatarImgOptions, AvatarSize } from "discourse/lib/avatar-utils";
import { avatarImg } from "discourse/lib/avatar-utils";

/**
 * Renders an avatar from its URL template, or a placeholder without one.
 *
 * @param avatarTemplate - The avatar URL template, with a `{size}` placeholder.
 * @param size - The size the avatar is shown at.
 * @param options - More `avatarImg` options.
 * @returns The trusted markup.
 */
export default function dBoundAvatarTemplate(
  avatarTemplate: string | null | undefined,
  size: AvatarSize,
  options?: Partial<AvatarImgOptions>
) {
  if (isEmpty(avatarTemplate)) {
    return trustHTML("<div class='avatar-placeholder'></div>");
  } else {
    return trustHTML(avatarImg({ size, avatarTemplate, ...options }));
  }
}
