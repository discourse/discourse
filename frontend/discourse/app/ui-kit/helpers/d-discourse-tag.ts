import { trustHTML } from "@ember/template";
import renderTag, {
  type RenderableTag,
  type RenderTagOptions,
} from "discourse/lib/render-tag";

/**
 * Renders a tag.
 *
 * @param name - The tag.
 * @param params - The options for `renderTag`.
 * @returns The tag HTML.
 */
export default function dDiscourseTag(
  name: RenderableTag,
  params?: RenderTagOptions | null
) {
  return trustHTML(renderTag(name, params));
}
