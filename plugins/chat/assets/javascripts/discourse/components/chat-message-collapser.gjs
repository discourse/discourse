import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import { and } from "truth-helpers";
import DecoratedHtml from "discourse/components/decorated-html";
import domFromString from "discourse/lib/dom-from-string";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import ChatUpload from "discourse/plugins/chat/discourse/components/chat-upload";
import Collapser from "discourse/plugins/chat/discourse/components/collapser";
import lightbox from "../lib/lightbox";

export default class ChatMessageCollapser extends Component {
  @service siteSettings;

  lightbox = modifier((element) => {
    if (this.args.uploads.length > 0) {
      lightbox(element.querySelectorAll("img.chat-img-upload"));
    }
  });

  get hasUploads() {
    return hasUploads(this.args.uploads);
  }

  get uploadsHeader() {
    let name = "";
    if (this.args.uploads.length === 1) {
      name = this.args.uploads[0].original_filename;
    } else {
      name = i18n("chat.uploaded_files", { count: this.args.uploads.length });
    }
    return htmlSafe(
      `<span class="chat-message-collapser-link-small">${escapeExpression(
        name
      )}</span>`
    );
  }

  get cookedBodies() {
    const elements = Array.prototype.slice.call(
      domFromString(this.args.cooked)
    );

    if (hasLazyVideo(elements)) {
      return this.lazyVideoCooked(elements);
    }

    if (hasImageOnebox(elements)) {
      return this.imageOneboxCooked(elements);
    }

    if (hasImage(elements)) {
      return this.imageCooked(elements);
    }

    if (hasGallery(elements)) {
      return this.galleryCooked(elements);
    }

    return [];
  }

  get lazyVideoComponent() {
    const path =
      "discourse/plugins/discourse-lazy-videos/discourse/components/lazy-video";
    return require.has(path) && require(path).default;
  }

  lazyVideoCooked(elements) {
    return elements.reduce((acc, e) => {
      if (this.siteSettings.lazy_videos_enabled && lazyVideoPredicate(e)) {
        const getVideoAttributes = requirejs(
          "discourse/plugins/discourse-lazy-videos/lib/lazy-video-attributes"
        ).default;

        const videoAttributes = getVideoAttributes(e);

        if (this.siteSettings[`lazy_${videoAttributes.providerName}_enabled`]) {
          const link = escapeExpression(videoAttributes.url);
          const title = videoAttributes.title;
          const header = htmlSafe(
            `<a target="_blank" class="chat-message-collapser-link" rel="noopener noreferrer" href="${link}">${title}</a>`
          );

          acc.push({
            header,
            body: e.outerHTML,
            videoAttributes,
            needsCollapser: true,
          });
        } else {
          acc.push({ body: e.outerHTML, needsCollapser: false });
        }
      } else {
        acc.push({ body: e.outerHTML, needsCollapser: false });
      }
      return acc;
    }, []);
  }

  imageOneboxCooked(elements) {
    return elements.reduce((acc, e) => {
      if (imageOneboxPredicate(e)) {
        let link = animatedImagePredicate(e)
          ? e.firstChild.src
          : e.firstElementChild.href;

        link = escapeExpression(link);
        const header = htmlSafe(
          `<a target="_blank" class="chat-message-collapser-link-small" rel="noopener noreferrer" href="${link}">${link}</a>`
        );
        acc.push({ header, body: e.outerHTML, needsCollapser: true });
      } else {
        acc.push({ body: e.outerHTML, needsCollapser: false });
      }
      return acc;
    }, []);
  }

  imageCooked(elements) {
    return elements.reduce((acc, e) => {
      if (imagePredicate(e)) {
        const link = escapeExpression(e.firstElementChild.src);
        const alt = escapeExpression(e.firstElementChild.alt);
        const header = htmlSafe(
          `<a target="_blank" class="chat-message-collapser-link-small" rel="noopener noreferrer" href="${link}">${
            alt || link
          }</a>`
        );
        acc.push({ header, body: e.outerHTML, needsCollapser: true });
      } else {
        acc.push({ body: e.outerHTML, needsCollapser: false });
      }
      return acc;
    }, []);
  }

  galleryCooked(elements) {
    return elements.reduce((acc, e) => {
      if (galleryPredicate(e)) {
        const link = escapeExpression(e.firstElementChild.href);
        const title = escapeExpression(
          e.firstElementChild.firstElementChild.textContent
        );
        e.firstElementChild.removeChild(e.firstElementChild.firstElementChild);
        const header = htmlSafe(
          `<a target="_blank" class="chat-message-collapser-link-small" rel="noopener noreferrer" href="${link}">${title}</a>`
        );
        acc.push({ header, body: e.outerHTML, needsCollapser: true });
      } else {
        acc.push({ body: e.outerHTML, needsCollapser: false });
      }
      return acc;
    }, []);
  }

  <template>
    <div class="chat-message-collapser">
      {{#if this.hasUploads}}
        <DecoratedHtml
          @html={{htmlSafe @cooked}}
          @decorate={{@decorate}}
          @className="chat-cooked"
        />

        <Collapser
          @header={{this.uploadsHeader}}
          @onToggle={{@onToggleCollapse}}
        >
          <div class="chat-uploads" {{this.lightbox}}>
            {{#each @uploads as |upload|}}
              <ChatUpload @upload={{upload}} />
            {{/each}}
          </div>
        </Collapser>
      {{else}}
        {{#each this.cookedBodies as |cooked|}}
          {{#if cooked.needsCollapser}}
            <Collapser
              @header={{cooked.header}}
              @onToggle={{@onToggleCollapse}}
            >
              {{#if (and cooked.videoAttributes this.lazyVideoComponent)}}
                <div class="chat-message-collapser-lazy-video">
                  <this.lazyVideoComponent
                    @videoAttributes={{cooked.videoAttributes}}
                  />
                </div>
              {{else}}
                <DecoratedHtml
                  @html={{htmlSafe cooked.body}}
                  @decorate={{@decorate}}
                  @className="chat-cooked"
                />
              {{/if}}
            </Collapser>
          {{else}}
            <DecoratedHtml
              @html={{htmlSafe cooked.body}}
              @decorate={{@decorate}}
              @className="chat-cooked"
            />
          {{/if}}
        {{/each}}
      {{/if}}
    </div>
  </template>
}

function lazyVideoPredicate(e) {
  return e.classList.contains("lazy-video-container");
}

function hasLazyVideo(elements) {
  return elements.some((e) => lazyVideoPredicate(e));
}

function animatedImagePredicate(e) {
  return (
    e.firstChild &&
    e.firstChild.nodeName === "IMG" &&
    e.firstChild.classList.contains("animated") &&
    e.firstChild.classList.contains("onebox")
  );
}

function externalImageOnebox(e) {
  return (
    e.firstElementChild &&
    e.firstElementChild.nodeName === "A" &&
    e.firstElementChild.classList.contains("onebox") &&
    e.firstElementChild.firstElementChild &&
    e.firstElementChild.firstElementChild.nodeName === "IMG"
  );
}

function imageOneboxPredicate(e) {
  return animatedImagePredicate(e) || externalImageOnebox(e);
}

function hasImageOnebox(elements) {
  return elements.some((e) => imageOneboxPredicate(e));
}

function hasUploads(uploads) {
  return uploads?.length > 0;
}

function imagePredicate(e) {
  return (
    e.nodeName === "P" &&
    e.firstElementChild &&
    e.firstElementChild.nodeName === "IMG" &&
    !e.firstElementChild.classList.contains("emoji")
  );
}

function hasImage(elements) {
  return elements.some((e) => imagePredicate(e));
}

function galleryPredicate(e) {
  return (
    e.firstElementChild &&
    e.firstElementChild.nodeName === "A" &&
    e.firstElementChild.firstElementChild &&
    e.firstElementChild.firstElementChild.classList.contains("outer-box")
  );
}

function hasGallery(elements) {
  return elements.some((e) => galleryPredicate(e));
}

export function isCollapsible(cooked, uploads) {
  const elements = Array.prototype.slice.call(domFromString(cooked));

  return (
    hasLazyVideo(elements) ||
    hasImageOnebox(elements) ||
    hasUploads(uploads) ||
    hasImage(elements) ||
    hasGallery(elements)
  );
}
