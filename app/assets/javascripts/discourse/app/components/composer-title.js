import Component from "@ember/component";
import EmberObject from "@ember/object";
import { alias, or } from "@ember/object/computed";
import { next, schedule } from "@ember/runloop";
import { classNames } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import { load } from "pretty-text/oneboxer";
import { lookupCache } from "pretty-text/oneboxer-cache";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import discourseComputed from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import putCursorAtEnd from "discourse/lib/put-cursor-at-end";
import { i18n } from "discourse-i18n";

@classNames("title-input")
export default class ComposerTitle extends Component {
  @alias("composer.canEditTopicFeaturedLink") watchForLink;
  @or("composer.loading", "composer.disableTitleInput") disabled;

  isTitleFocused = false;

  didInsertElement() {
    super.didInsertElement(...arguments);
    const titleInput = this.element.querySelector("input");

    this._focusHandler = () => this.set("isTitleFocused", true);
    this._blurHandler = () => this.set("isTitleFocused", false);

    titleInput.addEventListener("focus", this._focusHandler);
    titleInput.addEventListener("blur", this._blurHandler);

    if (this.focusTarget === "title") {
      putCursorAtEnd(titleInput);
    }

    if (this.get("composer.titleLength") > 0) {
      discourseDebounce(this, this._titleChanged, 10);
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    const titleInput = this.element.querySelector("input");

    if (titleInput) {
      titleInput.removeEventListener("focus", this._focusHandler);
      titleInput.removeEventListener("blur", this._blurHandler);
    }
  }

  @discourseComputed(
    "composer.titleLength",
    "composer.missingTitleCharacters",
    "composer.minimumTitleLength",
    "lastValidatedAt",
    "isTitleFocused"
  )
  validation(
    titleLength,
    missingTitleChars,
    minimumTitleLength,
    lastValidatedAt,
    isTitleFocused
  ) {
    let reason;
    if (isTitleFocused) {
      return;
    }
    if (titleLength < 1) {
      reason = i18n("composer.error.title_missing");
    } else if (missingTitleChars > 0) {
      reason = i18n("composer.error.title_too_short", {
        count: minimumTitleLength,
      });
    } else if (titleLength > this.siteSettings.max_topic_title_length) {
      reason = i18n("composer.error.title_too_long", {
        count: this.siteSettings.max_topic_title_length,
      });
    }

    if (reason) {
      return EmberObject.create({
        failed: true,
        reason,
        lastShownAt: lastValidatedAt,
      });
    }
  }

  @discourseComputed("watchForLink")
  titleMaxLength(watchForLink) {
    // maxLength gets in the way of pasting long links, so don't use it if featured links are allowed.
    // Validation will display a message if titles are too long.
    return watchForLink ? null : this.siteSettings.max_topic_title_length;
  }

  @observes("composer.titleLength", "watchForLink")
  _titleChanged() {
    if (this.get("composer.titleLength") === 0) {
      this.set("autoPosted", false);
    }
    if (this.autoPosted || !this.watchForLink) {
      return;
    }

    if (isTesting()) {
      next(() =>
        // not ideal but we don't want to run this in current
        // runloop to avoid an error in console
        this._checkForUrl()
      );
    } else {
      discourseDebounce(this, this._checkForUrl, 500);
    }
  }

  @observes("composer.replyLength")
  _clearFeaturedLink() {
    if (this.watchForLink && this.bodyIsDefault()) {
      this.set("composer.featuredLink", null);
    }
  }

  _checkForUrl() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    if (this.isAbsoluteUrl && this.bodyIsDefault()) {
      // only feature links to external sites
      if (
        this.get("composer.title").match(
          new RegExp("^https?:\\/\\/" + window.location.hostname, "i")
        )
      ) {
        return;
      }

      // Try to onebox. If success, update post body and title.
      this.set("composer.loading", true);

      const link = document.createElement("a");
      link.href = this.get("composer.title");

      const loadOnebox = load({
        elem: link,
        refresh: false,
        ajax,
        synchronous: true,
        categoryId: this.get("composer.category.id"),
        topicId: this.get("composer.topic.id"),
      });

      if (loadOnebox && loadOnebox.then) {
        loadOnebox
          .then(() => {
            const v = lookupCache(this.get("composer.title"));
            this._updatePost(v ? v : link);
          })
          .finally(() => {
            this.set("composer.loading", false);
            schedule("afterRender", () => {
              putCursorAtEnd(this.element.querySelector("input"));
            });
          });
      } else {
        this._updatePost(loadOnebox);
        this.set("composer.loading", false);
        schedule("afterRender", () => {
          putCursorAtEnd(this.element.querySelector("input"));
        });
      }
    }
  }

  _updatePost(html) {
    if (html) {
      const frag = document.createRange().createContextualFragment(html),
        composer = this.composer;

      this.set("autoPosted", true);
      this.set("composer.featuredLink", this.get("composer.title"));

      composer.appendText(this.get("composer.title"), null, { block: true });

      if (frag.querySelector(".twitterstatus")) {
        this.set("composer.title", "");
        return;
      }

      const heading = frag.querySelector("h3, h4");

      const title =
        (heading && heading.textContent) ||
        (frag.firstElementChild && frag.firstElementChild.title);

      if (title) {
        this.changeTitle(title);
      } else {
        const firstTitle =
          (frag.firstChild &&
            frag.firstChild.attributes &&
            frag.firstChild.attributes.title) ||
          (frag.querySelector("[title]") &&
            frag.querySelector("[title]").attributes.title);

        if (firstTitle) {
          this.changeTitle(firstTitle);
        }
      }
    }
  }

  changeTitle(val) {
    if (val && val.length > 0) {
      this.set("composer.title", val.trim());
    }
  }

  @discourseComputed("composer.title", "composer.titleLength")
  isAbsoluteUrl(title, titleLength) {
    return (
      titleLength > 0 &&
      /^(https?:)?\/\/[\w\.\-]+/i.test(title) &&
      !/\s/.test(title)
    );
  }

  bodyIsDefault() {
    const reply = this.get("composer.reply") || "";
    return (
      reply.length === 0 ||
      reply === (this.get("composer.category.topic_template") || "")
    );
  }
}
