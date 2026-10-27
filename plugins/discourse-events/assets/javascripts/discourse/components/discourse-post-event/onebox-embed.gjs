import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { withPluginApi } from "discourse/lib/plugin-api";
import { optionalRequire } from "discourse/lib/utilities";

// Renders a server-cooked onebox inside the event card. For supported video
// providers we hand the resolved attributes to lazy-videos' LazyVideo component
// (the post-stream decorator that normally does this doesn't reach our card);
// otherwise we render the onebox as-is.
export default class DiscoursePostEventOneboxEmbed extends Component {
  @service siteSettings;

  // Resolved at runtime: lazy-videos may not be installed, and resolving at
  // module load can return false before the plugin's modules are registered.
  get lazyVideo() {
    return optionalRequire(
      "discourse/plugins/discourse-lazy-videos/discourse/components/lazy-video"
    );
  }

  get videoAttributes() {
    const html = this.args.html;
    const getVideoAttributes = optionalRequire(
      "discourse/plugins/discourse-lazy-videos/lib/lazy-video-attributes"
    );
    if (!html || !getVideoAttributes || !this.lazyVideo) {
      return null;
    }

    const container = new DOMParser()
      .parseFromString(html, "text/html")
      .querySelector(".lazy-video-container");
    if (!container) {
      return null;
    }

    const attributes = getVideoAttributes(container);
    return this.siteSettings[`lazy_${attributes.providerName}_enabled`]
      ? attributes
      : null;
  }

  get oneboxHtml() {
    return this.videoAttributes ? null : trustHTML(this.args.html ?? "");
  }

  // Once playback starts the post has to stay rendered: cloaking it tears down
  // the component holding the video, taking any joined session with it.
  @action
  preventCloak() {
    const postId = this.args.post?.id;

    if (postId) {
      withPluginApi((api) => api.preventCloak(postId));
    }
  }

  <template>
    {{#if this.videoAttributes}}
      <this.lazyVideo
        @onLoadedVideo={{this.preventCloak}}
        @videoAttributes={{this.videoAttributes}}
      />
    {{else}}
      {{this.oneboxHtml}}
    {{/if}}
  </template>
}
