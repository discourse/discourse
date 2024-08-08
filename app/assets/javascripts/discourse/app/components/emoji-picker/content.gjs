import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { later, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier as modifierFn } from "ember-modifier";
import { eq, gt, includes, notEq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import noop from "discourse/helpers/noop";
import replaceEmoji from "discourse/helpers/replace-emoji";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { emojiUrlFor } from "discourse/lib/text";
import { INPUT_DELAY } from "discourse-common/config/environment";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import discourseDebounce from "discourse-common/lib/debounce";
import { makeArray } from "discourse-common/lib/helpers";
import { bind } from "discourse-common/utils/decorators";
import DcFilterInput from "discourse/plugins/chat/discourse/components/dc-filter-input";

export const FITZPATRICK_MODIFIERS = [
  { scale: 1, modifier: null },
  { scale: 2, modifier: ":t2" },
  { scale: 3, modifier: ":t3" },
  { scale: 4, modifier: ":t4" },
  { scale: 5, modifier: ":t5" },
  { scale: 6, modifier: ":t6" },
];

const DEFAULT_VISIBLE_SECTIONS = ["favorites", "smileys_&_emotion"];
const DEFAULT_LAST_SECTION = "favorites";

const tonableEmojiTitle = (emoji, diversity) => {
  if (!emoji.tonable || diversity === 1) {
    return `:${emoji.name}:`;
  }

  return `:${emoji.name}:t${diversity}:`;
};

const tonableEmojiUrl = (emoji, scale) => {
  if (!emoji.tonable || scale === 1) {
    return emoji.url;
  }

  return emoji.url.split(".png")[0] + `/${scale}.png`;
};

export default class EmojiPicker extends Component {
  @service emojiReactionStore;
  @service capabilities;
  @service site;

  @tracked filteredEmojis = null;
  @tracked isExpandedFitzpatrickScale = false;
  @tracked scrollObserverEnabled = true;
  @tracked scrollDirection = "up";
  @tracked emojis = null;
  @tracked visibleSections = DEFAULT_VISIBLE_SECTIONS;
  @tracked lastVisibleSection = DEFAULT_LAST_SECTION;

  prevYPosition = 0;

  fitzpatrickModifiers = FITZPATRICK_MODIFIERS;

  scrollListener = modifierFn((element) => {
    element.addEventListener("scroll", this._handleScroll);

    return () => {
      element.removeEventListener("scroll", this._handleScroll);
    };
  });

  addVisibleSections(sections) {
    this.visibleSections = makeArray(this.visibleSections)
      .concat(makeArray(sections))
      .uniq();
  }

  get sections() {
    return !this.loading && this.emojis ? Object.keys(this.emojis) : [];
  }

  get groups() {
    const favorites = {
      favorites: this.emojiReactionStore.favorites
        .filter((f) => !this.site.denied_emojis?.includes(f))
        .map((name) => {
          return {
            name,
            group: "favorites",
            url: emojiUrlFor(name),
          };
        }),
    };

    return {
      ...favorites,
      ...this.emojis,
    };
  }

  get flatEmojis() {
    if (!this.emojis) {
      return [];
    }

    // eslint-disable-next-line no-unused-vars
    let { favorites, ...rest } = this.emojis;
    return Object.values(rest).flat();
  }

  get navIndicatorStyle() {
    const section = this.lastVisibleSection;
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
        .querySelector(`.emoji-picker__scrollable-content .emoji[tabindex="0"]`)
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
        .closest(".emoji-picker__fitzpatrick-scale")
        ?.querySelectorAll(".emoji-picker__fitzpatrick-modifier-btn") || [];

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
      // TODO: FIX?
      // if (event.key === "Escape") {
      //   event.preventDefault();
      //   this.isExpandedFitzpatrickScale = false;
      //   return;
      // }

      if (event.key !== "Enter") {
        return;
      }
    }

    this.isExpandedFitzpatrickScale = !this.isExpandedFitzpatrickScale;
  }

  @action
  didRequestFitzpatrickScale(scale, event) {
    if (event.type === "keyup") {
      // TODO: FIX?
      // if (event.key === "Escape") {
      //   event.preventDefault();
      //   event.stopPropagation();
      //   this.isExpandedFitzpatrickScale = false;
      //   this._focusCurrentFitzpatrickScale();
      //   return;
      // }

      if (event.key !== "Enter") {
        return;
      }
    }

    event.preventDefault();
    event.stopPropagation();

    this.isExpandedFitzpatrickScale = false;
    this.emojiReactionStore.diversity = scale;
    this._focusCurrentFitzpatrickScale();
  }

  _focusCurrentFitzpatrickScale() {
    schedule("afterRender", () => {
      document
        .querySelector(".emoji-picker__fitzpatrick-modifier-btn.current")
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
    schedule("afterRender", () => {
      target?.focus();
    });
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
        ".emoji-picker__scrollable-content"
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
    const currentSection = event.target.closest(".emoji-picker__section");
    const focusFilter = () => {
      document.querySelector(".dc-filter-input")?.focus();
    };
    const allEmojis = () => [
      ...document.querySelectorAll(
        ".emoji-picker__section:not(.hidden) .emoji"
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
  async didSelectEmoji(event) {
    if (!event.target.classList.contains("emoji")) {
      return;
    }

    if (event.type === "click" || event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
      let emoji = event.target.dataset.emoji;
      const tonable = event.target.dataset.tonable;
      const diversity = this.emojiReactionStore.diversity;
      if (tonable && diversity > 1) {
        emoji = `${emoji}:t${diversity}`;
      }

      this.args.didSelectEmoji?.(emoji);

      await this.args.close();
    }
  }

  @action
  didRequestSection(section) {
    const scrollableContent = document.querySelector(
      ".emoji-picker__scrollable-content"
    );

    this.filteredEmojis = null;

    // we disable scroll listener during requesting section
    // to avoid it from detecting another section during scroll to requested section
    this.scrollObserverEnabled = false;
    this.addVisibleSections([section]);
    this.lastVisibleSection = section;

    // iOS hack to avoid blank div when requesting section during momentum
    if (scrollableContent && this.capabilities.isIOS) {
      document.querySelector(
        ".emoji-picker__scrollable-content"
      ).style.overflow = "hidden";
    }

    schedule("afterRender", () => {
      const firstEmoji = document.querySelector(
        `.emoji-picker__section[data-section="${section}"] .emoji:nth-child(1)`
      );

      const targetEmoji =
        [
          ...document.querySelectorAll(
            `.emoji-picker__section[data-section="${section}"] .emoji`
          ),
        ].find((emoji) => emoji.offsetTop > firstEmoji.offsetTop) || firstEmoji;

      targetEmoji.focus();

      later(() => {
        // iOS hack to avoid blank div when requesting section during momentum
        if (scrollableContent && this.capabilities.isIOS) {
          document.querySelector(
            ".emoji-picker__scrollable-content"
          ).style.overflow = "scroll";
        }

        this.scrollObserverEnabled = true;
      }, 200);
    });
  }

  @action
  async loadEmojis() {
    if (this.emojis) {
      return;
    }

    this.loading = true;

    try {
      const emojis = await ajax("/chat/emojis.json");
      this.emojis = emojis;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @bind
  _handleScroll(event) {
    if (!this.scrollObserverEnabled) {
      return;
    }

    this._setScrollDirection(event.target);

    const visibleSections = [
      ...document.querySelectorAll(".emoji-picker__section"),
    ].filter((sectionElement) =>
      this._isSectionVisibleInPicker(sectionElement, event.target)
    );

    if (visibleSections?.length) {
      let sectionElement;

      if (this.scrollDirection === "up" || this.prevYPosition < 50) {
        sectionElement = visibleSections.firstObject;
      } else {
        sectionElement = visibleSections.lastObject;
      }

      this.lastVisibleSection = sectionElement.dataset.section;
      this.addVisibleSections(visibleSections.map((s) => s.dataset.section));
    }
  }

  _setScrollDirection(target) {
    if (target.scrollTop > this.prevYPosition) {
      this.scrollDirection = "down";
    } else {
      this.scrollDirection = "up";
    }

    this.prevYPosition = target.scrollTop;
  }

  _isSectionVisibleInPicker(section, picker) {
    const { bottom, height, top } = section.getBoundingClientRect();
    const containerRect = picker.getBoundingClientRect();

    return top <= containerRect.top
      ? containerRect.top - top <= height
      : bottom - containerRect.bottom <= height;
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    {{! template-lint-disable no-nested-interactive }}
    {{! template-lint-disable no-pointer-down-event-binding }}
    <div
      class={{concatClass "emoji-picker"}}
      {{didInsert this.loadEmojis}}
      {{didInsert (if @didInsert @didInsert (noop))}}
      {{willDestroy (if @willDestroy @willDestroy (noop))}}
      {{on "keydown" this.trapKeyDownEvents}}
      ...attributes
    >
      <div class="emoji-picker__filter-container">
        <DcFilterInput
          {{didInsert (if this.site.desktopView this.focusFilter (noop))}}
          {{didInsert (fn this.didInputFilter @term)}}
          @value={{@term}}
          @filterAction={{withEventValue this.didInputFilter}}
          @icons={{hash left="search"}}
          @containerClass="emoji-picker__filter"
          autofocus={{true}}
          placeholder={{i18n "chat.emoji_picker.search_placeholder"}}
        >
          <div
            class="emoji-picker__fitzpatrick-scale"
            role="toolbar"
            {{on "keyup" this.didNavigateFitzpatrickScale}}
          >
            {{#if this.isExpandedFitzpatrickScale}}
              {{#each this.fitzpatrickModifiers as |fitzpatrick|}}

                {{#if
                  (notEq fitzpatrick.scale this.emojiReactionStore.diversity)
                }}
                  <button
                    type="button"
                    title={{concat "t" fitzpatrick.scale}}
                    tabindex="-1"
                    class={{concatClass
                      "emoji-picker__fitzpatrick-modifier-btn"
                      (concat "t" fitzpatrick.scale)
                    }}
                    {{on
                      "keyup"
                      (fn this.didRequestFitzpatrickScale fitzpatrick.scale)
                    }}
                    {{on
                      "click"
                      (fn this.didRequestFitzpatrickScale fitzpatrick.scale)
                    }}
                  >
                    {{icon "check"}}
                  </button>
                {{/if}}
              {{/each}}
            {{/if}}

            <button
              type="button"
              title={{concat "t" this.fitzpatrick.scale}}
              class={{concatClass
                "emoji-picker__fitzpatrick-modifier-btn current"
                (concat "t" this.emojiReactionStore.diversity)
              }}
              {{on "keyup" this.didToggleFitzpatrickScale}}
              {{on "click" this.didToggleFitzpatrickScale}}
            ></button>
          </div>
        </DcFilterInput>
      </div>

      {{#if this.sections.length}}
        {{#if (eq this.filteredEmojis null)}}
          <div class="emoji-picker__sections-nav">
            <div
              class="emoji-picker__sections-nav__indicator"
              style={{this.navIndicatorStyle}}
            ></div>

            {{#each-in this.groups as |section emojis|}}
              <DButton
                class={{concatClass
                  "btn-flat"
                  "emoji-picker__section-btn"
                  (if (eq this.lastVisibleSection section) "active")
                }}
                tabindex="-1"
                style={{this.navBtnStyle}}
                @action={{fn this.didRequestSection section}}
                data-section={{section}}
              >
                {{#if (eq section "favorites")}}
                  {{replaceEmoji ":star:"}}
                {{else}}
                  <img
                    width="18"
                    height="18"
                    class="emoji"
                    src={{get emojis "0.url"}}
                  />
                {{/if}}
              </DButton>
            {{/each-in}}
          </div>
        {{/if}}

        <div class="emoji-picker__scrollable-content" {{this.scrollListener}}>
          <div
            class="emoji-picker__sections"
            {{on "click" this.didSelectEmoji}}
            {{on "keydown" this.onSectionsKeyDown}}
            role="button"
          >
            {{#if (notEq this.filteredEmojis null)}}
              <div class="emoji-picker__section filtered">
                {{#each this.filteredEmojis as |emoji|}}
                  <img
                    width="32"
                    height="32"
                    class="emoji"
                    src={{tonableEmojiUrl
                      emoji
                      this.emojiReactionStore.diversity
                    }}
                    tabindex="0"
                    data-emoji={{emoji.name}}
                    data-tonable={{if emoji.tonable "true"}}
                    alt={{emoji.name}}
                    title={{tonableEmojiTitle
                      emoji
                      this.emojiReactionStore.diversity
                    }}
                    loading="lazy"
                  />
                {{else}}
                  <p class="emoji-picker__no-results">
                    {{i18n "chat.emoji_picker.no_results"}}
                  </p>
                {{/each}}
              </div>
            {{/if}}

            {{#each-in this.groups as |section emojis|}}
              <div
                class={{concatClass
                  "emoji-picker__section"
                  (if (notEq this.filteredEmojis null) "hidden")
                }}
                data-section={{section}}
                role="region"
                aria-label={{i18n
                  (concat "chat.emoji_picker." section)
                  translatedFallback=section
                }}
              >
                <h2 class="emoji-picker__section-title">
                  {{i18n
                    (concat "chat.emoji_picker." section)
                    translatedFallback=section
                  }}
                </h2>
                <div class="emoji-picker__section-emojis">
                  {{! we always want the first emoji for tabbing}}
                  {{#let (get emojis "0") as |emoji|}}
                    <img
                      width="32"
                      height="32"
                      class="emoji"
                      src={{tonableEmojiUrl
                        emoji
                        this.emojiReactionStore.diversity
                      }}
                      tabindex="0"
                      data-emoji={{emoji.name}}
                      data-tonable={{if emoji.tonable "true"}}
                      alt={{emoji.name}}
                      title={{tonableEmojiTitle
                        emoji
                        this.emojiReactionStore.diversity
                      }}
                      loading="lazy"
                    />
                  {{/let}}

                  {{#if (includes this.visibleSections section)}}
                    {{#each emojis as |emoji index|}}
                      {{! first emoji has already been rendered, we don't want to re render or would lose focus}}
                      {{#if (gt index 0)}}
                        <img
                          width="32"
                          height="32"
                          class="emoji"
                          src={{tonableEmojiUrl
                            emoji
                            this.emojiReactionStore.diversity
                          }}
                          tabindex="-1"
                          data-emoji={{emoji.name}}
                          data-tonable={{if emoji.tonable "true"}}
                          alt={{emoji.name}}
                          title={{tonableEmojiTitle
                            emoji
                            this.emojiReactionStore.diversity
                          }}
                          loading="lazy"
                        />
                      {{/if}}
                    {{/each}}
                  {{/if}}
                </div>
              </div>
            {{/each-in}}
          </div>
        </div>
      {{else}}
        <div class="spinner medium"></div>
      {{/if}}
    </div>
  </template>
}
