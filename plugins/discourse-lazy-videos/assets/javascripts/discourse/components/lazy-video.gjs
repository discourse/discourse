import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import LazyIframe from "./lazy-iframe";

export default class LazyVideo extends Component {
  @tracked isLoaded = false;

  get thumbnailStyle() {
    const color = this.args.videoAttributes.dominantColor;
    if (color?.match(/^[0-9A-Fa-f]+$/)) {
      return trustHTML(`background-color: #${color};`);
    }
  }

  @action
  loadEmbed() {
    if (!this.isLoaded) {
      this.isLoaded = true;
      this.args.onLoadedVideo?.();
    }
  }

  @action
  onKeyPress(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.loadEmbed();
    }
  }

  <template>
    <div
      class={{dConcatClass
        "lazy-video-container"
        (concat @videoAttributes.providerName "-onebox")
        (if this.isLoaded "video-loaded")
      }}
      data-provider-name={{@videoAttributes.providerName}}
      data-video-id={{@videoAttributes.id}}
      data-video-list-id={{@videoAttributes.listId}}
      data-video-start-time={{@videoAttributes.startTime}}
      data-video-title={{@videoAttributes.title}}
    >
      {{#if this.isLoaded}}
        <LazyIframe
          @listId={{@videoAttributes.listId}}
          @providerName={{@videoAttributes.providerName}}
          @startTime={{@videoAttributes.startTime}}
          @title={{@videoAttributes.title}}
          @videoId={{@videoAttributes.id}}
        />
      {{else}}
        <div
          aria-label={{i18n
            "lazy_videos.play_video"
            title=@videoAttributes.title
          }}
          class={{dConcatClass "video-thumbnail" @videoAttributes.providerName}}
          role="button"
          style={{this.thumbnailStyle}}
          tabindex="0"
          {{on "click" this.loadEmbed}}
          {{on "keypress" this.onKeyPress}}
        >
          <img
            class={{concat @videoAttributes.providerName "-thumbnail"}}
            loading="lazy"
            src={{@videoAttributes.thumbnail}}
            title={{@videoAttributes.title}}
          />
          <div
            class={{dConcatClass
              "icon"
              (concat @videoAttributes.providerName "-icon")
            }}
          ></div>
        </div>
        <div class="title-container">
          <div class="title-wrapper">
            <a
              class="title-link"
              href={{@videoAttributes.url}}
              rel="noopener noreferrer"
              target="_blank"
              title={{@videoAttributes.title}}
            >
              {{@videoAttributes.title}}
            </a>
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
