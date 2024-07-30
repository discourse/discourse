import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import LazyIframe from "./lazy-iframe";

export default class LazyVideo extends Component {
  @tracked isLoaded = false;

  get thumbnailStyle() {
    const color = this.args.videoAttributes.dominantColor;
    if (color?.match(/^[0-9A-Fa-f]+$/)) {
      return htmlSafe(`background-color: #${color};`);
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
    if (event.key === "Enter") {
      event.preventDefault();
      this.loadEmbed();
    }
  }

  <template>
    <div
      data-video-id={{@videoAttributes.id}}
      data-video-title={{@videoAttributes.title}}
      data-video-start-time={{@videoAttributes.startTime}}
      data-provider-name={{@videoAttributes.providerName}}
      class={{concatClass
        "lazy-video-container"
        (concat @videoAttributes.providerName "-onebox")
        (if this.isLoaded "video-loaded")
      }}
    >
      {{#if this.isLoaded}}
        <LazyIframe
          @providerName={{@videoAttributes.providerName}}
          @title={{@videoAttributes.title}}
          @videoId={{@videoAttributes.id}}
          @startTime={{@videoAttributes.startTime}}
        />
      {{else}}
        <div
          {{on "click" this.loadEmbed}}
          {{on "keypress" this.loadEmbed}}
          tabindex="0"
          style={{this.thumbnailStyle}}
          class={{concatClass "video-thumbnail" @videoAttributes.providerName}}
        >
          <img
            src={{@videoAttributes.thumbnail}}
            title={{@videoAttributes.title}}
            loading="lazy"
            class={{concat @videoAttributes.providerName "-thumbnail"}}
          />
          <div
            class={{concatClass
              "icon"
              (concat @videoAttributes.providerName "-icon")
            }}
          ></div>
        </div>
        <div class="title-container">
          <div class="title-wrapper">
            <a
              href={{@videoAttributes.url}}
              title={{@videoAttributes.title}}
              target="_blank"
              rel="noopener noreferrer"
              class="title-link"
            >
              {{@videoAttributes.title}}
            </a>
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
