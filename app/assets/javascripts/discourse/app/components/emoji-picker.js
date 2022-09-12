import { action, computed } from "@ember/object";
import discourseComputed, {
  bind,
  observes,
} from "discourse-common/utils/decorators";
import {
  emojiSearch,
  extendedEmojiList,
  isSkinTonableEmoji,
} from "pretty-text/emoji";
import { emojiUnescape, emojiUrlFor } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { schedule } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";
import discourseDebounce from "discourse-common/lib/debounce";
import Component from "@ember/component";
import { createPopper } from "@popperjs/core";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";
import { underscore } from "@ember/string";

function customEmojis() {
  const list = extendedEmojiList();
  const groups = [];
  for (const [code, emoji] of list.entries()) {
    groups[emoji.group] = groups[emoji.group] || [];
    groups[emoji.group].push({
      code,
      src: emojiUrlFor(code),
    });
  }
  return groups;
}

export default Component.extend({
  emojiStore: service("emoji-store"),
  tagName: "",
  customEmojis: null,
  recentEmojis: null,
  hoveredEmoji: null,
  isActive: false,
  usePopper: true,
  placement: "auto", // one of popper.js' placements, see https://popper.js.org/docs/v2/constructors/#options
  initialFilter: "",
  elements: {
    searchBar: ".emoji-picker-search-container input",
    emojiResults: ".emoji-picker-emoji-area .results .emoji",
    allEmojis: ".emojis-container .emoji",
    picker: ".emoji-picker-emoji-area",
  },

  init() {
    this._super(...arguments);

    this.set("customEmojis", customEmojis());

    if ("IntersectionObserver" in window) {
      this._sectionObserver = this._setupSectionObserver();
    }
  },

  didInsertElement() {
    this._super(...arguments);

    this.appEvents.on("emoji-picker:close", this, "onClose");
  },

  // `readOnly` may seem like a better choice here, but the computed property
  // provides caching (emojiStore.diversity is a simple getter)
  @discourseComputed("emojiStore.diversity")
  selectedDiversity(diversity) {
    return diversity;
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
    this.set("recentEmojis", this.emojiStore.favorites);

    schedule("afterRender", () => {
      this._applyFilter(this.initialFilter);
      document.addEventListener("click", this.handleOutsideClick);

      const emojiPicker = document.querySelector(".emoji-picker");
      if (!emojiPicker) {
        return;
      }
      const popperAnchor = this._getPopperAnchor();
      this._getNumEmojiPerRow(".emojis-container .emoji");

      if (!this.site.isMobileDevice && this.usePopper && popperAnchor) {
        const modifiers = [
          {
            name: "preventOverflow",
          },
          {
            name: "offset",
            options: {
              offset: [5, 5],
            },
          },
        ];

        if (
          this.placement === "auto" &&
          window.innerWidth < popperAnchor.clientWidth * 2
        ) {
          modifiers.push({
            name: "computeStyles",
            enabled: true,
            fn({ state }) {
              state.styles.popper = {
                ...state.styles.popper,
                position: "fixed",
                left: `${(window.innerWidth - state.rects.popper.width) / 2}px`,
                top: "50%",
                transform: "translateY(-50%)",
              };

              return state;
            },
          });
        }

        this._popper = createPopper(popperAnchor, emojiPicker, {
          placement: this.placement,
        });
      }

      // this is a low-tech trick to prevent appending hundreds of emojis
      // of blocking the rendering of the picker
      discourseLater(() => {
        schedule("afterRender", () => {
          if (!this.site.isMobileDevice || this.isEditorFocused) {
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
  onClose(event) {
    event?.stopPropagation();
    document.removeEventListener("click", this.handleOutsideClick);
    this.onEmojiPickerClose && this.onEmojiPickerClose(event);
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
  onClearRecent() {
    this.emojiStore.favorites = [];
    this.set("recentEmojis", []);
  },

  @action
  onDiversitySelection(index) {
    const scale = index + 1;
    this.emojiStore.diversity = scale;

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

    this._trackEmojiUsage(code, {
      refresh: !img.parentNode.parentNode.classList.contains("recent"),
    });

    if (this.site.isMobileDevice) {
      this.onClose(event);
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
  keydown(event) {
    const arrowKeys = ["ArrowDown", "ArrowUp", "ArrowLeft", "ArrowRight"];
    const searchBar = document.querySelector(this.elements.searchBar);
    let emojis = document.querySelectorAll(this.elements.emojiResults);

    // if no search results get all emojis
    if (emojis.length === 0) {
      emojis = document.querySelectorAll(this.elements.allEmojis);
    }

    if (
      event.code === "ArrowDown" &&
      this._focusedOn(this.elements.searchBar)
    ) {
      return emojis[0].focus();
    }

    if (event.code === "Escape") {
      this.onClose(event);
      return false;
    }

    if (arrowKeys.includes(event.code)) {
      if (!this._focusedOn(this.elements.picker)) {
        return;
      }

      let currentEmoji;
      // identify the currently active emoji:
      emojis.forEach((e, index) => {
        if (e.isEqualNode(document.activeElement)) {
          e.focus();
          currentEmoji = index;
          return currentEmoji;
        }
      });

      const numEmojisInRow = this.get("emojiPerRow");

      // ! TODO fix recent jumping when down arrow

      emojis[currentEmoji].focus();

      if (event.code === "ArrowRight") {
        const nextEmoji = currentEmoji + 1;
        if (nextEmoji < emojis.length) {
          emojis[nextEmoji].focus();
        }
      }

      if (event.code === "ArrowLeft") {
        const previousEmoji = currentEmoji - 1;
        if (currentEmoji > 0) {
          emojis[previousEmoji].focus();
        }
      }

      if (event.code === "ArrowDown") {
        const emojiNextRow = currentEmoji + numEmojisInRow;
        if (emojiNextRow < emojis.length) {
          emojis[emojiNextRow].focus();
        }
      }

      if (event.code === "ArrowUp") {
        const emojiPreviousRow = currentEmoji - numEmojisInRow;
        const emojiInFirstRow = 0 + numEmojisInRow;

        if (emojiPreviousRow >= 0) {
          emojis[emojiPreviousRow].focus();
        }

        if (currentEmoji < emojiInFirstRow) {
          searchBar.focus();
        }
      }

      event.preventDefault();
      return false;
    }

    if (event.code === "Enter") {
      if (!this._focusedOn(".emoji")) {
        return;
      }
      this.onEmojiSelection(event);
      this.onClose(event);
      event.preventDefault();
      return false;
    }
  },

  @action
  onFilterChange(event) {
    this._applyFilter(event.target.value);

    discourseDebounce(
      this,
      () => {
        if (event.target.value === "") {
          this._getNumEmojiPerRow(this.elements.allEmojis, false);
        } else {
          this._getNumEmojiPerRow(this.elements.emojiResults, true);
        }
      },
      500
    );
  },

  _getNumEmojiPerRow(emojiSelector, isSearching = false) {
    // ! TODO: this.recentEmojis array length?
    // See: https://stackoverflow.com/a/49888033
    const emojis = document.querySelectorAll(emojiSelector);
    if (!emojis || emojis.length === 0) {
      return;
    }

    const container = document.querySelector(
      ".emojis-container .section-group"
    );
    const rowLength = Math.floor(container.clientWidth / emojis[0].clientWidth);
    const totalEmojis = emojis.length;
    const numElementsLastRow = totalEmojis % rowLength;

    if (isSearching) {
      return this.set("emojiPerRow", rowLength);
    } else {
      return this.set("emojiPerRow", rowLength - numElementsLastRow);
    }
  },

  _focusedOn(item) {
    // returns the item currently being focused on
    return document.activeElement.closest(item) ? document.activeElement : null;
  },

  _applyFilter(filter) {
    const emojiPicker = document.querySelector(".emoji-picker");
    const results = document.querySelector(".emoji-picker-emoji-area .results");
    results.innerHTML = "";

    if (filter) {
      results.innerHTML = emojiSearch(filter.toLowerCase(), {
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

  _trackEmojiUsage(code, options = {}) {
    this.emojiStore.track(code);

    if (options.refresh) {
      this.set("recentEmojis", [...this.emojiStore.favorites]);
    }
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

  _getPopperAnchor() {
    // .d-editor-textarea-wrapper is only for backward compatibility here
    // in new code use .emoji-picker-anchor
    return (
      document.querySelector(".emoji-picker-anchor") ??
      document.querySelector(".d-editor-textarea-wrapper")
    );
  },

  @bind
  handleOutsideClick(event) {
    const emojiPicker = document.querySelector(".emoji-picker");
    if (emojiPicker && !emojiPicker.contains(event.target)) {
      this.onClose(event);
    }
  },
});
