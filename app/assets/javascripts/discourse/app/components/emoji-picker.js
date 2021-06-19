import { action, computed } from "@ember/object";
import { bind, observes } from "discourse-common/utils/decorators";
import {
  emojiSearch,
  extendedEmojiList,
  isSkinTonableEmoji,
} from "pretty-text/emoji";
import { emojiUnescape, emojiUrlFor } from "discourse/lib/text";
import { escapeExpression, safariHacksDisabled } from "discourse/lib/utilities";
import { later, schedule } from "@ember/runloop";
import Component from "@ember/component";
import { createPopper } from "@popperjs/core";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";
import { underscore } from "@ember/string";

function customEmojis() {
  const list = extendedEmojiList();
  const groups = [];
  Object.keys(list).forEach((code) => {
    const emoji = list[code];
    groups[emoji.group] = groups[emoji.group] || [];
    groups[emoji.group].push({
      code,
      src: emojiUrlFor(code),
    });
  });
  return groups;
}

export default Component.extend({
  emojiStore: service("emoji-store"),
  tagName: "",
  customEmojis: null,
  selectedDiversity: null,
  recentEmojis: null,
  hoveredEmoji: null,
  isActive: false,
  isLoading: true,

  init() {
    this._super(...arguments);

    this.set("customEmojis", customEmojis());
    this.set("recentEmojis", this.emojiStore.favorites);
    this.set("selectedDiversity", this.emojiStore.diversity);

    if ("IntersectionObserver" in window) {
      this._sectionObserver = this._setupSectionObserver();
    }
  },

  didInsertElement() {
    this._super(...arguments);

    this.appEvents.on("emoji-picker:close", this, "onClose");
  },

  // didReceiveAttrs would be a better choice here, but this is sadly causing
  // too many unexpected reloads as it's triggered for other reasons than a mutation
  // of isActive
  @observes("isActive")
  _setup() {
    if (this.isActive) {
      this.onShow();
    } else {
      this.onClose();
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    this._sectionObserver && this._sectionObserver.disconnect();

    this.appEvents.off("emoji-picker:close", this, "onClose");
  },

  @action
  onShow() {
    this.set("isLoading", true);

    schedule("afterRender", () => {
      document.addEventListener("click", this.handleOutsideClick);

      const emojiPicker = document.querySelector(".emoji-picker");
      if (!emojiPicker) {
        return;
      }

      if (!this.site.isMobileDevice) {
        this._popper = createPopper(
          document.querySelector(".d-editor-textarea-wrapper"),
          emojiPicker,
          {
            placement: "auto",
            modifiers: [
              {
                name: "preventOverflow",
              },
              {
                name: "offset",
                options: {
                  offset: [5, 5],
                },
              },
            ],
          }
        );
      }

      // this is a low-tech trick to prevent appending hundreds of emojis
      // of blocking the rendering of the picker
      later(() => {
        this.set("isLoading", false);

        schedule("afterRender", () => {
          if (
            (!this.site.isMobileDevice || this.isEditorFocused) &&
            !safariHacksDisabled()
          ) {
            const filter = emojiPicker.querySelector("input.filter");
            filter && filter.focus();

            if (this._sectionObserver) {
              emojiPicker
                .querySelectorAll(".emojis-container .section .section-header")
                .forEach((p) => this._sectionObserver.observe(p));
            }
          }

          if (this.selectedDiversity !== 0) {
            this._applyDiversity(this.selectedDiversity);
          }
        });
      }, 50);
    });
  },

  @action
  onClose() {
    document.removeEventListener("click", this.handleOutsideClick);
    this.onEmojiPickerClose && this.onEmojiPickerClose();
  },

  diversityScales: computed("selectedDiversity", function () {
    return [
      "default",
      "light",
      "medium-light",
      "medium",
      "medium-dark",
      "dark",
    ].map((name, index) => {
      return {
        name,
        title: `emoji_picker.${underscore(name)}_tone`,
        icon: index + 1 === this.selectedDiversity ? "check" : "",
      };
    });
  }),

  @action
  onClearRecents() {
    this.emojiStore.favorites = [];
    this.set("recentEmojis", []);
  },

  @action
  onDiversitySelection(index) {
    const scale = index + 1;
    this.emojiStore.diversity = scale;
    this.set("selectedDiversity", scale);

    this._applyDiversity(scale);
  },

  @action
  onEmojiHover(event) {
    const img = event.target;
    if (!img.classList.contains("emoji") || img.tagName !== "IMG") {
      return false;
    }

    this.set(
      "hoveredEmoji",
      this._codeWithDiversity(event.target.title, this.selectedDiversity)
    );
  },

  @action
  onEmojiSelection(event) {
    const img = event.target;

    if (!img.classList.contains("emoji") || img.tagName !== "IMG") {
      return false;
    }

    let code = event.target.title;
    code = this._codeWithDiversity(code, this.selectedDiversity);

    this.emojiSelected(code);

    if (!img.parentNode.parentNode.classList.contains("recent")) {
      this._trackEmojiUsage(code);
    }

    if (this.site.isMobileDevice) {
      this.onClose();
    }
  },

  @action
  onCategorySelection(sectionName) {
    const section = document.querySelector(
      `.emoji-picker-emoji-area .section[data-section="${sectionName}"]`
    );
    section && section.scrollIntoView();
  },

  @action
  onFilter(event) {
    const emojiPicker = document.querySelector(".emoji-picker");
    const results = document.querySelector(".emoji-picker-emoji-area .results");
    results.innerHTML = "";

    if (event.target.value) {
      results.innerHTML = emojiSearch(event.target.value.toLowerCase(), {
        maxResults: 20,
        diversity: this.emojiStore.diversity,
      })
        .map(this._replaceEmoji)
        .join("");

      emojiPicker.classList.add("has-filter");
      results.scrollIntoView();
    } else {
      emojiPicker.classList.remove("has-filter");
    }
  },

  _trackEmojiUsage(code) {
    this.emojiStore.track(code);
    this.set("recentEmojis", this.emojiStore.favorites.slice(0, 10));
  },

  _replaceEmoji(code) {
    const escaped = emojiUnescape(`:${escapeExpression(code)}:`, {
      lazy: true,
    });
    return htmlSafe(`<span>${escaped}</span>`);
  },

  _codeWithDiversity(code, selectedDiversity) {
    if (/:t\d/.test(code)) {
      return code;
    } else if (selectedDiversity > 1 && isSkinTonableEmoji(code)) {
      return `${code}:t${selectedDiversity}`;
    } else {
      return code;
    }
  },

  _applyDiversity(diversity) {
    const emojiPickerArea = document.querySelector(".emoji-picker-emoji-area");

    emojiPickerArea &&
      emojiPickerArea.querySelectorAll(".emoji.diversity").forEach((img) => {
        const code = this._codeWithDiversity(img.title, diversity);
        img.src = emojiUrlFor(code);
      });
  },

  _setupSectionObserver() {
    return new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const sectionName = entry.target.parentNode.dataset.section;
            const categoryButtons = document.querySelector(
              ".emoji-picker .emoji-picker-category-buttons"
            );

            if (!categoryButtons) {
              return;
            }

            const button = categoryButtons.querySelector(
              `.category-button[data-section="${sectionName}"]`
            );

            categoryButtons
              .querySelectorAll(".category-button")
              .forEach((b) => b.classList.remove("current"));
            button && button.classList.add("current");
          }
        });
      },
      { threshold: 1 }
    );
  },

  @bind
  handleOutsideClick(event) {
    const emojiPicker = document.querySelector(".emoji-picker");
    if (emojiPicker && !emojiPicker.contains(event.target)) {
      this.onClose();
    }
  },
});
