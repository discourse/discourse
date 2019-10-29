import Component from "@ember/component";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import InputValidation from "discourse/models/input-validation";
import { load, lookupCache } from "pretty-text/oneboxer";
import { ajax } from "discourse/lib/ajax";
import afterTransition from "discourse/lib/after-transition";

export default Component.extend({
  classNames: ["title-input"],
  watchForLink: Ember.computed.alias("composer.canEditTopicFeaturedLink"),
  disabled: Ember.computed.or("composer.loading", "composer.disableTitleInput"),

  didInsertElement() {
    this._super(...arguments);
    if (this.focusTarget === "title") {
      const $input = $(this.element.querySelector("input"));

      afterTransition($(this.element).closest("#reply-control"), () => {
        $input.putCursorAtEnd();
      });
    }

    if (this.get("composer.titleLength") > 0) {
      Ember.run.debounce(this, this._titleChanged, 10);
    }
  },

  @computed(
    "composer.titleLength",
    "composer.missingTitleCharacters",
    "composer.minimumTitleLength",
    "lastValidatedAt"
  )
  validation(
    titleLength,
    missingTitleChars,
    minimumTitleLength,
    lastValidatedAt
  ) {
    let reason;
    if (titleLength < 1) {
      reason = I18n.t("composer.error.title_missing");
    } else if (missingTitleChars > 0) {
      reason = I18n.t("composer.error.title_too_short", {
        min: minimumTitleLength
      });
    } else if (titleLength > this.siteSettings.max_topic_title_length) {
      reason = I18n.t("composer.error.title_too_long", {
        max: this.siteSettings.max_topic_title_length
      });
    }

    if (reason) {
      return InputValidation.create({
        failed: true,
        reason,
        lastShownAt: lastValidatedAt
      });
    }
  },

  @computed("watchForLink")
  titleMaxLength() {
    // maxLength gets in the way of pasting long links, so don't use it if featured links are allowed.
    // Validation will display a message if titles are too long.
    return this.watchForLink ? null : this.siteSettings.max_topic_title_length;
  },

  @observes("composer.titleLength", "watchForLink")
  _titleChanged() {
    if (this.get("composer.titleLength") === 0) {
      this.set("autoPosted", false);
    }
    if (this.autoPosted || !this.watchForLink) {
      return;
    }

    if (Ember.testing) {
      Ember.run.next(() =>
        // not ideal but we don't want to run this in current
        // runloop to avoid an error in console
        this._checkForUrl()
      );
    } else {
      Ember.run.debounce(this, this._checkForUrl, 500);
    }
  },

  @observes("composer.replyLength")
  _clearFeaturedLink() {
    if (this.watchForLink && this.bodyIsDefault()) {
      this.set("composer.featuredLink", null);
    }
  },

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
        topicId: this.get("composer.topic.id")
      });

      if (loadOnebox && loadOnebox.then) {
        loadOnebox
          .then(() => {
            const v = lookupCache(this.get("composer.title"));
            this._updatePost(v ? v : link);
          })
          .finally(() => {
            this.set("composer.loading", false);
            Ember.run.schedule("afterRender", () => {
              $(this.element.querySelector("input")).putCursorAtEnd();
            });
          });
      } else {
        this._updatePost(loadOnebox);
        this.set("composer.loading", false);
        Ember.run.schedule("afterRender", () => {
          $(this.element.querySelector("input")).putCursorAtEnd();
        });
      }
    }
  },

  _updatePost(html) {
    if (html) {
      this.set("autoPosted", true);
      this.set("composer.featuredLink", this.get("composer.title"));

      const $h = $(html),
        heading = $h.find("h3").length > 0 ? $h.find("h3") : $h.find("h4"),
        composer = this.composer;

      composer.appendText(this.get("composer.title"), null, { block: true });

      if (heading.length > 0 && heading.text().length > 0) {
        this.changeTitle(heading.text());
      } else {
        const firstTitle = $h.attr("title") || $h.find("[title]").attr("title");
        if (firstTitle && firstTitle.length > 0) {
          this.changeTitle(firstTitle);
        }
      }
    }
  },

  changeTitle(val) {
    if (val && val.length > 0) {
      this.set("composer.title", val.trim());
    }
  },

  @computed("composer.title", "composer.titleLength")
  isAbsoluteUrl(title, titleLength) {
    return (
      titleLength > 0 &&
      /^(https?:)?\/\/[\w\.\-]+/i.test(title) &&
      !/\s/.test(title)
    );
  },

  bodyIsDefault() {
    const reply = this.get("composer.reply") || "";
    return (
      reply.length === 0 ||
      reply === (this.get("composer.category.topic_template") || "")
    );
  }
});
