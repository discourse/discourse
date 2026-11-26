import { trustHTML } from "@ember/template";
import renderTags, {
  type RenderTagsOptions,
  type TagsTopic,
} from "discourse/lib/render-tags";

/**
 * Renders a topic's tags as a list.
 *
 * @param topic - The topic.
 * @param params - The options for `renderTags`.
 * @returns The list HTML.
 */
export default function dDiscourseTags(
  topic: TagsTopic | null | undefined,
  params?: RenderTagsOptions | null
) {
  return trustHTML(renderTags(topic, params));
}
