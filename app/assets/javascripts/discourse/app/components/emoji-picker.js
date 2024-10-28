import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { underscore } from "@ember/string";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import { createPopper } from "@popperjs/core";
import {
  emojiSearch,
  extendedEmojiList,
  isSkinTonableEmoji,
} from "pretty-text/emoji";
import { emojiUnescape, emojiUrlFor } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import discourseLater from "discourse-common/lib/later";
import discourseComputed, {
  bind,
  observes,
} from "discourse-common/utils/decorators";

function customEmojis() {
  const groups = [];
  for (const [code, emoji] of extendedEmojiList()) {
    groups[emoji.group] ||= [];
    groups[emoji.group].push({ code, src: emojiUrlFor(code) });
  }
  return groups;
}

@tagName("")
export default class EmojiPicker extends Component {
  @service("emoji-store") emojiStore;

  customEmojis = customEmojis();
  recentEmojis = null;
  hoveredEmoji = null;
  isActive = false;
  usePopper = true;
  placement = "auto"; // one of popper.js' placements, see https://popper.js.org/docs/v2/constructors/#options
  initialFilter = "";

  elements = {
    searchInput: ".emoji-picker-search-container input",
    picker: ".emoji-picker-emoji-area",
  };

  init() {
    super.init(...arguments);
    this._sectionObserver = this._setupSectionObserver();
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.appEvents.on("emoji-picker:close", this, "onClose");
  }

  // `readOnly` may seem like a better choice here, but the computed property
  // provides caching (emojiStore.diversity is a simple getter)
  @discourseComputed("emojiStore.diversity")
  selectedDiversity(diversity) {
    return diversity;
  }

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
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this._sectionObserver?.disconnect();
    this.appEvents.off("emoji-picker:close", this, "onClose");
  }

  @action
  onShow() {
    this.set("recentEmojis", this.emojiStore.favorites);

    schedule("afterRender", () => {
      this._applyFilter(this.initialFilter);

      const emojiPicker = document.querySelector(".emoji-picker");
      if (!emojiPicker) {
        return;
      }

      document.addEventListener("click", this.handleOutsideClick);

      const popperAnchor = this._getPopperAnchor();

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
            emojiPicker.querySelector("input.filter")?.focus();

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
  }

  @action
  onClose(event) {
    event?.stopPropagation();
    document.removeEventListener("click", this.handleOutsideClick);
    this.onEmojiPickerClose?.(event);
  }

  @computed("selectedDiversity")
  get diversityScales() {
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
  }

  @action
  onClearRecent() {
    this.emojiStore.favorites = [];
    this.set("recentEmojis", []);
  }

  @action
  onDiversitySelection(index) {
    const scale = index + 1;
    this.emojiStore.diversity = scale;

    this._applyDiversity(scale);
  }

  @action
  onEmojiHover(event) {
    const img = event.target;
    if (!img.classList.contains("emoji") || img.tagName !== "IMG") {
      return false;
    }

    this._updateEmojiPreview(event.target.title);
  }

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
  }

  @action
  onCategorySelection(sectionName, event) {
    event?.preventDefault();
    document
      .querySelector(
        `.emoji-picker-emoji-area .section[data-section="${sectionName}"]`
      )
      ?.scrollIntoView();
  }

  @action
  keydown(event) {
    const arrowKeys = ["ArrowDown", "ArrowUp", "ArrowLeft", "ArrowRight"];
    const emojis = document.querySelectorAll(".emoji-picker-emoji-area .emoji");

    let currentEmoji;

    if (
      event.key === "ArrowDown" &&
      this._focusedOn(this.elements.searchInput)
    ) {
      this._updateEmojiPreview(emojis[0].title);
      emojis[0].focus();
      event.preventDefault();
      return false;
    }

    if (event.key === "Escape") {
      this.onClose(event);
      const path = event.path || event.composedPath?.();

      const fromChatComposer = path.find((e) =>
        e?.classList?.contains("chat-composer-container")
      );

      const fromTopicComposer = path.find((e) =>
        e?.classList?.contains("d-editor")
      );

      if (fromTopicComposer) {
        document.querySelector(".d-editor-input")?.focus();
      } else if (fromChatComposer) {
        document.querySelector(".chat-composer__input")?.focus();
      } else {
        document.querySelector("textarea")?.focus();
      }

      return false;
    }

    if (arrowKeys.includes(event.key)) {
      if (!this._focusedOn(this.elements.picker)) {
        return;
      }

      Array.from(emojis).find((e, index) => {
        currentEmoji = index;
        return e.isEqualNode(event.target);
      });

      if (event.key === "ArrowRight") {
        let nextEmoji = currentEmoji + 1;

        if (nextEmoji < emojis.length) {
          this._updateEmojiPreview(emojis[nextEmoji].title);
          emojis[nextEmoji].focus();
        } else if (nextEmoji >= emojis.length) {
          this._updateEmojiPreview(emojis[0].title);
          emojis[0].focus();
        }
      }

      if (event.key === "ArrowLeft") {
        const previousEmoji = currentEmoji - 1;
        if (currentEmoji > 0) {
          this._updateEmojiPreview(emojis[previousEmoji].title);
          emojis[previousEmoji].focus();
        }
      }

      const active = emojis[currentEmoji];

      if (event.key === "ArrowDown") {
        // source: https://stackoverflow.com/a/49090383/349424
        // look for same element type with
        // - higher offsetTop
        // - same offsetLeft
        const emojiBelow = [...emojis]
          .filter((c) => c.offsetTop > active.offsetTop)
          .find((c) => c.offsetLeft === active.offsetLeft);
        if (emojiBelow) {
          this._updateEmojiPreview(emojiBelow.title);
          emojiBelow.focus();
        }
      }

      if (event.key === "ArrowUp") {
        // look for same element type with
        // - lower offsetTop
        // - same offsetLeft
        const emojiAbove = [...emojis]
          .reverse()
          .filter((c) => c.offsetTop < active.offsetTop)
          .find((c) => c.offsetLeft === active.offsetLeft);

        if (emojiAbove) {
          this._updateEmojiPreview(emojiAbove.title);
          emojiAbove.focus();
        } else {
          this.set("hoveredEmoji", null);
          document.querySelector(this.elements.searchInput).focus();
        }
      }

      event.preventDefault();
      return false;
    }

    if (event.key === "Enter") {
      if (!this._focusedOn(".emoji")) {
        return;
      }
      this.onEmojiSelection(event);
      this.onClose(event);
      event.preventDefault();
      return false;
    }
  }

  @action
  onFilterChange(event) {
    this._applyFilter(event.target.value);
  }

  _focusedOn(item) {
    // returns the item currently being focused on
    return document.activeElement.closest(item) ? document.activeElement : null;
  }

  _applyFilter(filter) {
    const emojiPicker = document.querySelector(".emoji-picker");
    const results = document.querySelector(".emoji-picker-emoji-area .results");
    results.innerHTML = "";

    if (filter) {
      results.innerHTML = emojiSearch(filter.toLowerCase(), {
        diversity: this.emojiStore.diversity,
        exclude: this.site.denied_emojis,
      })
        .map(this._replaceEmoji)
        .join("");

      emojiPicker.classList.add("has-filter");
      results.scrollIntoView();
    } else {
      emojiPicker.classList.remove("has-filter");
    }
  }

  _trackEmojiUsage(code, options = {}) {
    this.emojiStore.track(code);

    if (options.refresh) {
      this.set("recentEmojis", [...this.emojiStore.favorites]);
    }
  }

  _replaceEmoji(code) {
    const escaped = emojiUnescape(`:${escapeExpression(code)}:`, {
      lazy: true,
      tabIndex: "0",
    });
    return htmlSafe(escaped);
  }

  _codeWithDiversity(code, selectedDiversity) {
    if (/:t\d/.test(code)) {
      return code;
    } else if (selectedDiversity > 1 && isSkinTonableEmoji(code)) {
      return `${code}:t${selectedDiversity}`;
    } else {
      return code;
    }
  }

  _applyDiversity(diversity) {
    const emojiPickerArea = document.querySelector(".emoji-picker-emoji-area");
    emojiPickerArea?.querySelectorAll(".emoji.diversity").forEach((img) => {
      img.src = emojiUrlFor(this._codeWithDiversity(img.title, diversity));
    });
  }

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

            categoryButtons
              .querySelectorAll(".category-button")
              .forEach((b) => b.classList.remove("current"));

            categoryButtons
              .querySelector(`.category-button[data-section="${sectionName}"]`)
              ?.classList?.add("current");
          }
        });
      },
      { threshold: 1 }
    );
  }

  _getPopperAnchor() {
    // .d-editor-textarea-wrapper is only for backward compatibility here
    // in new code use .emoji-picker-anchor
    return (
      document.querySelector(".emoji-picker-anchor") ??
      document.querySelector(".d-editor-textarea-wrapper")
    );
  }

  _updateEmojiPreview(title) {
    return this.set(
      "hoveredEmoji",
      this._codeWithDiversity(title, this.selectedDiversity)
    );
  }

  @bind
  handleOutsideClick(event) {
    if (!event.target.closest(".emoji-picker")) {
      this.onClose(event);
    }
  }
}
