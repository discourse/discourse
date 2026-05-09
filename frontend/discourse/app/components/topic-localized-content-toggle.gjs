import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { i18n } from "discourse-i18n";

const SHOW_ORIGINAL_COOKIE = "content-localization-show-original";
const SHOW_ORIGINAL_COOKIE_EXPIRY = 30;

export default class TopicLocalizedContentToggle extends Component {
  @service currentUser;
  @service router;
  @service toasts;

  @tracked showingOriginal = false;

  constructor() {
    super(...arguments);
    if (this.currentUser) {
      this.showingOriginal =
        this.currentUser.user_option?.show_original_content;
    } else {
      this.showingOriginal = cookie(SHOW_ORIGINAL_COOKIE);
    }
  }

  @action
  async showOriginal() {
    const newValue = !this.showingOriginal;

    if (this.currentUser) {
      this.currentUser.set("user_option.show_original_content", newValue);
      await ajax(`/u/${this.currentUser.username}.json`, {
        type: "PUT",
        data: { show_original_content: newValue },
      });
    } else if (newValue) {
      cookie(SHOW_ORIGINAL_COOKIE, true, {
        path: "/",
        expires: SHOW_ORIGINAL_COOKIE_EXPIRY,
      });
    } else {
      removeCookie(SHOW_ORIGINAL_COOKIE, { path: "/" });
    }

    const toastKey = this.showingOriginal
      ? "content_localization.toggle_localized.translations_enabled"
      : "content_localization.toggle_localized.translations_disabled";

    this.showingOriginal = newValue;

    const postStream = this.args.topic?.postStream;
    if (postStream) {
      const currentURL = this.router.currentURL;
      // this is required to clear the post stream cache
      // otherwise the old posts before the toggle will be shown
      postStream.removeAllPosts();
      await this.router.refresh();
      // refreshing clears the post number,
      // and postStream.refresh nearPost does not load to the correct post
      if (this.router.currentURL !== currentURL) {
        this.router.replaceWith(currentURL);
      }
    }

    this.toasts.success({
      duration: "short",
      data: { message: i18n(toastKey) },
    });
  }

  get title() {
    return this.showingOriginal
      ? "content_localization.toggle_localized.not_translated"
      : "content_localization.toggle_localized.translated";
  }

  <template>
    <DButton
      @icon="language"
      @title={{this.title}}
      class={{concatClass
        "btn btn-default btn-toggle-localized-content no-text"
        (unless this.showingOriginal "--active")
      }}
      @action={{this.showOriginal}}
    />
  </template>
}
