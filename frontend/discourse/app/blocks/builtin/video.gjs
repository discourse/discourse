// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { URL_PATTERN } from "discourse/lib/blocks";
import { i18n } from "discourse-i18n";

/**
 * A video player for a direct video file URL, with an optional poster image.
 * Complements `embed`: reach for `embed` to drop in a link a provider
 * oneboxes (YouTube, etc.); reach for `video` to play a hosted file with
 * native controls.
 */
@block("video", {
  thumbnail:
    /** @type {() => Promise<typeof import("discourse/blocks/thumbnails/video.gjs")>} */ (
      () => import("discourse/blocks/thumbnails/video")
    ),
  displayName: "Video",
  icon: "video",
  category: "Content",
  description: "Plays a video file, with an optional poster image.",
  args: {
    source: {
      type: "string",
      pattern: URL_PATTERN,
      ui: { control: "url", label: i18n("blocks.builtin.video.source") },
    },
    poster: {
      type: "image",
      allowResize: false,
      ui: { label: i18n("blocks.builtin.video.poster") },
    },
    autoplay: {
      type: "boolean",
      default: false,
      ui: { control: "toggle", label: i18n("blocks.builtin.video.autoplay") },
    },
    loop: {
      type: "boolean",
      default: false,
      ui: { control: "toggle", label: i18n("blocks.builtin.video.loop") },
    },
    muted: {
      type: "boolean",
      default: false,
      ui: { control: "toggle", label: i18n("blocks.builtin.video.muted") },
    },
    controls: {
      type: "boolean",
      default: true,
      ui: { control: "toggle", label: i18n("blocks.builtin.video.controls") },
    },
  },
})
export default class Video extends Component {
  <template>
    <video
      class="d-block-video"
      src={{@source}}
      poster={{@poster.url}}
      autoplay={{@autoplay}}
      loop={{@loop}}
      muted={{@muted}}
      controls={{@controls}}
      playsinline
      data-block-arg="source"
    ></video>
  </template>
}
