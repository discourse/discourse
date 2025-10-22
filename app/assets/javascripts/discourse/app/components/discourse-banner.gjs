import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import DecoratedHtml from "./decorated-html";

export default class DiscourseBanner extends Component {
  @service appEvents;
  @service currentUser;
  @service keyValueStore;
  @service site;

  @tracked hide = false;

  get banner() {
    return this.site.get("banner");
  }

  get content() {
    const bannerHtml = this.banner.html;
    const newDiv = document.createElement("div");
    newDiv.innerHTML = bannerHtml;
    newDiv.querySelectorAll("[id^='heading--']").forEach((el) => {
      el.removeAttribute("id");
    });
    return htmlSafe(newDiv.innerHTML);
  }

  get visible() {
    let dismissedBannerKey =
      this.currentUser?.dismissed_banner_key ||
      this.keyValueStore.get("dismissed_banner_key");
    let bannerKey = this.banner?.key;

    if (bannerKey) {
      bannerKey = parseInt(bannerKey, 10);
    }

    if (dismissedBannerKey) {
      dismissedBannerKey = parseInt(dismissedBannerKey, 10);
    }

    return !this.hide && bannerKey && dismissedBannerKey !== bannerKey;
  }

  @bind
  decorateContent(element, helper) {
    this.appEvents.trigger(
      "decorate-non-stream-cooked-element",
      element,
      helper
    );
  }

  @action
  dismiss() {
    if (this.currentUser) {
      this.currentUser.dismissBanner(this.banner.key);
    } else {
      this.hide = true;
      this.keyValueStore.set({
        key: "dismissed_banner_key",
        value: this.banner.key,
      });
    }
  }

  <template>
    {{#if this.visible}}
      <div class="container">
        <div class="row">
          <div id="banner">
            <div class="floated-buttons">
              {{#if this.currentUser.staff}}
                <a
                  href={{this.banner.url}}
                  class="btn btn-transparent edit-banner"
                >
                  {{icon "pencil"}}
                  {{#if this.site.desktopView}}
                    {{htmlSafe (i18n "banner.edit")}}
                  {{/if}}
                </a>
              {{/if}}

              <DButton
                @action={{this.dismiss}}
                @icon="xmark"
                @title="banner.close"
                class="btn-transparent close"
              />
            </div>

            <DecoratedHtml
              @html={{this.content}}
              @decorate={{this.decorateContent}}
              @id="banner-content"
            />
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
