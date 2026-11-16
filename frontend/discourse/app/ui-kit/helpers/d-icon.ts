import { trustHTML } from "@ember/template";
import type { IconParams } from "discourse/lib/icon-library";
import { renderIcon } from "discourse/lib/icon-library";

/**
 * Renders an icon.
 *
 * @param id - The icon id.
 * @param options - The named arguments, passed to the icon renderer.
 * @returns The trusted markup.
 */
export default function icon(id: string, options: IconParams = {}) {
  // The default icon renderer handles every icon.
  return trustHTML(renderIcon("string", id, options) as string);
}
