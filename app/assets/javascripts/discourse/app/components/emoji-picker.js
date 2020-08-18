import { htmlSafe } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import { emojiUrlFor } from "discourse/lib/text";
import {
  extendedEmojiList,
  isSkinTonableEmoji,
  emojiSearch
} from "pretty-text/emoji";
import { safariHacksDisabled } from "discourse/lib/utilities";

function customEmojis() {
  const list = extendedEmojiList();
  const groups = [];
  Object.keys(list).forEach(code => {
    const emoji = list[code];
    groups[emoji.group] = groups[emoji.group] || [];
    groups[emoji.group].push({
      code,
      src: emojiUrlFor(code)
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

  init() {
    this._super(...arguments);

    this.set("customEmojis", customEmojis());
    this.set("recentEmojis", this.emojiStore.favorites);
    this.set("selectedDiversity", this.emojiStore.diversity);

    this._sectionObserver = this._setupSectionObserver();
  },

  didReceiveAttrs() {
    this._super(...arguments);

    if (this.isActive) {
      this.onShow();
    } else {
      this.onClose();
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    this._sectionObserver && this._sectionObserver.disconnect();
  },

  @action
  onShow() {
    schedule("afterRender", () => {
      const emojiPicker = document.querySelector(".emoji-picker");
      if (!emojiPicker) return;

      if (
        (!this.site.isMobileDevice || this.isEditorFocused) &&
        !safariHacksDisabled()
      ) {
        const filter = emojiPicker.querySelector("input.filter");
        filter && filter.focus();
      }

      if (this.selectedDiversity !== 0) {
        this._applyDiversity(this.selectedDiversity);
      }

      if (!this.site.isMobileDevice) {
        /* global Popper:true */
        this._popper = Popper.createPopper(
          document.querySelector(".d-editor-textarea-wrapper"),
          emojiPicker,
          {
            placement: "auto",
            modifiers: [
              {
                name: "preventOverflow"
              },
              {
                name: "offset",
                options: {
                  offset: [5, 5]
                }
              }
            ]
          }
        );
      }

      emojiPicker
        .querySelectorAll(".emojis-container .section .section-header")
        .forEach(p => this._sectionObserver.observe(p));
    });
  },

  @action
  onClose() {
    this.onEmojiPickerClose && this.onEmojiPickerClose();
  },

  diversityScales: computed("selectedDiversity", function() {
    return [
      "default",
      "light",
      "medium-light",
      "medium",
      "medium-dark",
      "dark"
    ].map((name, index) => {
      return {
        name: name.replace(/-/g, "_"),
        icon: index === this.selectedDiversity ? "check" : ""
      };
    });
  }),

  @action
  onClearRecents() {
    this.emojiStore.favorites = [];
    this.set("recentEmojis", []);
  },

  @action
  onDiversitySelection(scale) {
    this.emojiStore.diversity = scale;
    this.set("selectedDiversity", scale);

    this._applyDiversity(scale);
  },

  @action
  onEmojiHover(event) {
    const img = event.target;
    if (!img.classList.contains("emoji") || !img.tagName === "IMG") {
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
    if (!img.classList.contains("emoji") || !img.tagName === "IMG") {
      return false;
    }

    let code = event.target.title;
    code = this._codeWithDiversity(code, this.selectedDiversity);
    this.emojiSelected(code);

    if (!img.parentNode.parentNode.classList.contains("recent")) {
      this._trackEmojiUsage(code);
    }

    this.onClose();
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
    const emojiPickerArea = document.querySelector(".emoji-picker-emoji-area");
    const emojisContainer = emojiPickerArea.querySelector(".emojis-container");
    const results = emojiPickerArea.querySelector(".results");
    results.innerHTML = "";

    if (event.target.value) {
      results.innerHTML = emojiSearch(event.target.value, { maxResults: 10 })
        .map(this._replaceEmoji)
        .join("");

      emojisContainer.style.visibility = "hidden";
      results.scrollIntoView();
    } else {
      emojisContainer.style.visibility = "visible";
    }
  },

  _trackEmojiUsage(code) {
    this.emojiStore.track(code);
    this.set("recentEmojis", this.emojiStore.favorites.slice(0, 10));
  },

  _replaceEmoji(code) {
    const escaped = emojiUnescape(`:${escapeExpression(code)}:`, {
      lazy: true
    });
    return htmlSafe(`<span>${escaped}</span>`);
  },

  _codeWithDiversity(code, selectedDiversity) {
    if (selectedDiversity !== 0 && isSkinTonableEmoji(code)) {
      return `${code}:t${selectedDiversity + 1}`;
    } else {
      return code;
    }
  },

  _applyDiversity(diversity) {
    const emojiPickerArea = document.querySelector(".emoji-picker-emoji-area");

    emojiPickerArea.querySelectorAll(".emoji.diversity").forEach(img => {
      const code = this._codeWithDiversity(img.title, diversity);
      img.src = emojiUrlFor(code);
    });
  },

  _setupSectionObserver() {
    return new IntersectionObserver(
      entries => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const sectionName = entry.target.parentNode.dataset.section;
            const categoryButtons = document.querySelector(
              ".emoji-picker .emoji-picker-category-buttons"
            );
            const button = categoryButtons.querySelector(
              `.category-button[data-section="${sectionName}"]`
            );
            categoryButtons
              .querySelectorAll(".category-button")
              .forEach(b => b.classList.remove("current"));
            button && button.classList.add("current");
          }
        });
      },
      { threshold: 1 }
    );
  }
});
