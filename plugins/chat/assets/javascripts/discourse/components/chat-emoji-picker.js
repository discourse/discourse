import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { emojiUrlFor } from "discourse/lib/text";
import discourseDebounce from "discourse-common/lib/debounce";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { bind } from "discourse-common/utils/decorators";
import { later, schedule } from "@ember/runloop";

export const FITZPATRICK_MODIFIERS = [
  {
    scale: 1,
    modifier: null,
  },
  {
    scale: 2,
    modifier: ":t2",
  },
  {
    scale: 3,
    modifier: ":t3",
  },
  {
    scale: 4,
    modifier: ":t4",
  },
  {
    scale: 5,
    modifier: ":t5",
  },
  {
    scale: 6,
    modifier: ":t6",
  },
];

export default class ChatEmojiPicker extends Component {
  @service chatEmojiPickerManager;
  @service emojiPickerScrollObserver;
  @service chatEmojiReactionStore;
  @service capabilities;
  @service site;

  @tracked filteredEmojis = null;
  @tracked isExpandedFitzpatrickScale = false;

  fitzpatrickModifiers = FITZPATRICK_MODIFIERS;

  get groups() {
    const emojis = this.chatEmojiPickerManager.emojis;
    const favorites = {
      favorites: this.chatEmojiReactionStore.favorites.map((name) => {
        return {
          name,
          group: "favorites",
          url: emojiUrlFor(name),
        };
      }),
    };

    return {
      ...favorites,
      ...emojis,
    };
  }

  get flatEmojis() {
    if (!this.chatEmojiPickerManager.emojis) {
      return [];
    }

    // eslint-disable-next-line no-unused-vars
    let { favorites, ...rest } = this.chatEmojiPickerManager.emojis;
    return Object.values(rest).flat();
  }

  get navIndicatorStyle() {
    const section = this.chatEmojiPickerManager.lastVisibleSection;
    const index = Object.keys(this.groups).indexOf(section);

    return htmlSafe(
      `width: ${
        100 / Object.keys(this.groups).length
      }%; transform: translateX(${index * 100}%);`
    );
  }

  get navBtnStyle() {
    return htmlSafe(`width: ${100 / Object.keys(this.groups).length}%;`);
  }

  @action
  trapKeyDownEvents(event) {
    if (event.key === "Escape") {
      this.chatEmojiPickerManager.close();
    }

    if (event.key === "ArrowUp") {
      event.stopPropagation();
    }

    if (
      event.key === "ArrowDown" &&
      event.target.classList.contains("dc-filter-input")
    ) {
      event.stopPropagation();
      event.preventDefault();

      document
        .querySelector(
          `.chat-emoji-picker__scrollable-content .emoji[tabindex="0"]`
        )
        ?.focus();
    }
  }

  @action
  didNavigateFitzpatrickScale(event) {
    if (event.type !== "keyup") {
      return;
    }

    const scaleNodes =
      event.target
        .closest(".chat-emoji-picker__fitzpatrick-scale")
        ?.querySelectorAll(".chat-emoji-picker__fitzpatrick-modifier-btn") ||
      [];

    const scales = [...scaleNodes];

    if (event.key === "ArrowRight") {
      event.preventDefault();

      if (event.target === scales[scales.length - 1]) {
        scales[0].focus();
      } else {
        event.target.nextElementSibling?.focus();
      }
    }

    if (event.key === "ArrowLeft") {
      event.preventDefault();

      if (event.target === scales[0]) {
        scales[scales.length - 1].focus();
      } else {
        event.target.previousElementSibling?.focus();
      }
    }
  }

  @action
  didToggleFitzpatrickScale(event) {
    if (event.type === "keyup") {
      if (event.key === "Escape") {
        event.preventDefault();
        this.isExpandedFitzpatrickScale = false;
        return;
      }

      if (event.key !== "Enter") {
        return;
      }
    }

    this.isExpandedFitzpatrickScale = !this.isExpandedFitzpatrickScale;
  }

  @action
  didRequestFitzpatrickScale(scale, event) {
    if (event.type === "keyup") {
      if (event.key === "Escape") {
        event.preventDefault();
        event.stopPropagation();
        this.isExpandedFitzpatrickScale = false;
        this._focusCurrentFitzpatrickScale();
        return;
      }

      if (event.key !== "Enter") {
        return;
      }
    }

    event.preventDefault();
    event.stopPropagation();

    this.isExpandedFitzpatrickScale = false;
    this.chatEmojiReactionStore.diversity = scale;
    this._focusCurrentFitzpatrickScale();
  }

  _focusCurrentFitzpatrickScale() {
    schedule("afterRender", () => {
      document
        .querySelector(".chat-emoji-picker__fitzpatrick-modifier-btn.current")
        ?.focus();
    });
  }

  @action
  didInputFilter(value) {
    if (!value?.length) {
      this.filteredEmojis = null;
      return;
    }

    discourseDebounce(this, this.debouncedDidInputFilter, value, INPUT_DELAY);
  }

  @action
  focusFilter(target) {
    target.focus();
  }

  debouncedDidInputFilter(filter = "") {
    filter = filter.toLowerCase();

    this.filteredEmojis = this.flatEmojis.filter(
      (emoji) =>
        emoji.name.toLowerCase().includes(filter) ||
        emoji.search_aliases?.any((alias) =>
          alias.toLowerCase().includes(filter)
        )
    );

    schedule("afterRender", () => {
      const scrollableContent = document.querySelector(
        ".chat-emoji-picker__scrollable-content"
      );

      if (scrollableContent) {
        scrollableContent.scrollTop = 0;
      }
    });
  }

  @action
  onSectionsKeyDown(event) {
    if (event.key === "Enter") {
      this.didSelectEmoji(event);
    } else {
      this.didNavigateSection(event);
    }
  }

  @action
  didNavigateSection(event) {
    const sectionsEmojis = (section) => [...section.querySelectorAll(".emoji")];
    const focusSectionsLastEmoji = (section) => {
      const emojis = sectionsEmojis(section);
      return emojis[emojis.length - 1].focus();
    };
    const focusSectionsFirstEmoji = (section) => {
      sectionsEmojis(section)[0].focus();
    };
    const currentSection = event.target.closest(".chat-emoji-picker__section");
    const focusFilter = () => {
      document.querySelector(".dc-filter-input")?.focus();
    };
    const allEmojis = () => [
      ...document.querySelectorAll(
        ".chat-emoji-picker__section:not(.hidden) .emoji"
      ),
    ];

    if (event.key === "ArrowRight") {
      event.preventDefault();
      const nextEmoji = event.target.nextElementSibling;

      if (nextEmoji) {
        nextEmoji.focus();
      } else {
        const nextSection = currentSection.nextElementSibling;
        if (nextSection) {
          focusSectionsFirstEmoji(nextSection);
        }
      }
    }

    if (event.key === "ArrowLeft") {
      event.preventDefault();
      const prevEmoji = event.target.previousElementSibling;

      if (prevEmoji) {
        prevEmoji.focus();
      } else {
        const prevSection = currentSection.previousElementSibling;
        if (prevSection) {
          focusSectionsLastEmoji(prevSection);
        } else {
          focusFilter();
        }
      }
    }

    if (event.key === "ArrowDown") {
      event.preventDefault();
      event.stopPropagation();

      const nextEmoji = allEmojis()
        .filter((c) => c.offsetTop > event.target.offsetTop)
        .findBy("offsetLeft", event.target.offsetLeft);

      if (nextEmoji) {
        nextEmoji.focus();
      } else {
        // for perf reason all emojis might not be loaded at this point
        // but the first one will always be
        const nextSection = currentSection.nextElementSibling;
        if (nextSection) {
          focusSectionsFirstEmoji(nextSection);
        }
      }
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();
      event.stopPropagation();

      const prevEmoji = allEmojis()
        .reverse()
        .filter((c) => c.offsetTop < event.target.offsetTop)
        .findBy("offsetLeft", event.target.offsetLeft);

      if (prevEmoji) {
        prevEmoji.focus();
      } else {
        focusFilter();
      }
    }
  }

  @action
  didSelectEmoji(event) {
    if (!event.target.classList.contains("emoji")) {
      return;
    }

    if (event.type === "click" || event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
      let emoji = event.target.dataset.emoji;
      const tonable = event.target.dataset.tonable;
      const diversity = this.chatEmojiReactionStore.diversity;
      if (tonable && diversity > 1) {
        emoji = `${emoji}:t${diversity}`;
      }

      this.args.didSelectEmoji?.(emoji);
    }
  }

  @action
  didFocusFirstEmoji(event) {
    event.preventDefault();
    const section = event.target.closest(".chat-emoji-picker__section").dataset
      .section;
    this.didRequestSection(section);
  }

  @action
  didRequestSection(section) {
    const scrollableContent = document.querySelector(
      ".chat-emoji-picker__scrollable-content"
    );

    this.filteredEmojis = null;

    // we disable scroll listener during requesting section
    // to avoid it from detecting another section during scroll to requested section
    this.emojiPickerScrollObserver.enabled = false;
    this.chatEmojiPickerManager.addVisibleSections([section]);
    this.chatEmojiPickerManager.lastVisibleSection = section;

    // iOS hack to avoid blank div when requesting section during momentum
    if (scrollableContent && this.capabilities.isIOS) {
      document.querySelector(
        ".chat-emoji-picker__scrollable-content"
      ).style.overflow = "hidden";
    }

    schedule("afterRender", () => {
      document
        .querySelector(`.chat-emoji-picker__section[data-section="${section}"]`)
        .scrollIntoView({
          behavior: "auto",
          block: "start",
          inline: "nearest",
        });

      later(() => {
        // iOS hack to avoid blank div when requesting section during momentum
        if (scrollableContent && this.capabilities.isIOS) {
          document.querySelector(
            ".chat-emoji-picker__scrollable-content"
          ).style.overflow = "scroll";
        }

        this.emojiPickerScrollObserver.enabled = true;
      }, 200);
    });
  }

  @action
  addClickOutsideEventListener() {
    document.addEventListener("click", this.didClickOutside);
  }

  @action
  removeClickOutsideEventListener() {
    document.removeEventListener("click", this.didClickOutside);
  }

  @bind
  didClickOutside(event) {
    if (!event.target.closest(".chat-emoji-picker")) {
      this.chatEmojiPickerManager.close();
    }
  }
}
