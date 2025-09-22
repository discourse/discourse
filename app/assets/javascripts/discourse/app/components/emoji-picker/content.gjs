import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import { emojiSearch, isSkinTonableEmoji } from "pretty-text/emoji";
import { eq, gt, includes, notEq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import FilterInput from "discourse/components/filter-input";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import noop from "discourse/helpers/noop";
import replaceEmoji from "discourse/helpers/replace-emoji";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  disableBodyScroll,
  enableBodyScroll,
} from "discourse/lib/body-scroll-lock";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import { makeArray } from "discourse/lib/helpers";
import loadEmojiSearchAliases from "discourse/lib/load-emoji-search-aliases";
import { emojiUrlFor } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import DiversityMenu from "./diversity-menu";

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
    return emojiUrlFor(emoji.name);
  }

  return emojiUrlFor(`${emoji.name}:t${scale}`);
};

export default class EmojiPicker extends Component {
  @service emojiStore;
  @service capabilities;
  @service site;

  @tracked isFiltering = false;
  @tracked filteredEmojis = null;
  @tracked scrollObserverEnabled = true;
  @tracked scrollDirection = "up";
  @tracked emojis = null;
  @tracked visibleSections = DEFAULT_VISIBLE_SECTIONS;
  @tracked lastVisibleSection = DEFAULT_LAST_SECTION;
  @tracked term = this.args.term;

  prevYPosition = 0;

  scrollableNode;

  setupSectionsNavScroll = modifierFn((element) => {
    disableBodyScroll(element);

    return () => {
      enableBodyScroll(element);
    };
  });

  scrollListener = modifierFn((element) => {
    this.scrollableNode = element;
    disableBodyScroll(element);
    element.addEventListener("scroll", this._handleScroll);

    return () => {
      this.scrollableNode = null;
      element.removeEventListener("scroll", this._handleScroll);
      enableBodyScroll(element);
    };
  });

  addVisibleSections(sections) {
    this.visibleSections = makeArray(this.visibleSections)
      .concat(makeArray(sections))
      .uniq();
  }

  get sections() {
    return !this.loading && this.emojiStore.list
      ? Object.keys(this.emojiStore.list)
      : [];
  }

  get groups() {
    const favorites = {
      favorites: this.emojiStore
        .favoritesForContext(this.args.context)
        .filter((f) => !this.site.denied_emojis?.includes(f))
        .map((emoji) => {
          return {
            name: emoji,
            group: "favorites",
            url: emojiUrlFor(emoji),
          };
        }),
    };

    return {
      ...favorites,
      ...this.emojiStore.list,
    };
  }

  @action
  registerFilterInput(element) {
    this.filterInput = element;
  }

  @action
  clearFavorites() {
    this.emojiStore.resetContext(this.args.context);
  }

  @action
  trapKeyDownEvents(event) {
    if (event.key === "ArrowUp") {
      event.stopPropagation();
    }

    if (event.key === "ArrowDown" && event.target === this.filterInput) {
      event.stopPropagation();
      event.preventDefault();

      this.scrollableNode.querySelector(`.emoji[tabindex="0"]`)?.focus();
    }
  }

  @action
  didInputFilter(value) {
    this.isFiltering = true;
    this.term = value;

    if (!value?.length) {
      cancel(this.debouncedFilterHandler);
      this.visibleSections = DEFAULT_VISIBLE_SECTIONS;
      this.filteredEmojis = null;
      this.isFiltering = false;
      return;
    }

    this.debouncedFilterHandler = discourseDebounce(
      this,
      this.debouncedDidInputFilter,
      value,
      INPUT_DELAY
    );
  }

  @action
  focusFilter(target) {
    if (this.capabilities.isIOS) {
      return;
    }

    target?.focus({ preventScroll: true });
  }

  debouncedDidInputFilter(filter = "") {
    filter = filter.toLowerCase();

    loadEmojiSearchAliases().then((searchAliases) => {
      const results = emojiSearch(filter, {
        exclude: this.site.denied_emojis,
        searchAliases,
      }).slice(0, 50);

      this.filteredEmojis = results.map((emoji) => {
        return {
          name: emoji,
          tonable: isSkinTonableEmoji(emoji),
        };
      });

      this.isFiltering = false;

      schedule("afterRender", () => {
        if (this.scrollableNode) {
          this.scrollableNode.scrollTop = 0;
        }
      });
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
      this.filterInput?.focus();
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
      const diversity = this.emojiStore.diversity;
      if (tonable && diversity > 1) {
        emoji = `${emoji}:t${diversity}`;
      }

      this.emojiStore.trackEmojiForContext(emoji, this.args.context);

      this.args.didSelectEmoji?.(emoji);

      await this.args.close?.();
    }
  }

  @action
  didRequestSection(section) {
    this.term = "";
    this.didInputFilter(null);

    // we disable scroll listener during requesting section
    // to avoid it from detecting another section during scroll to requested section
    this.scrollObserverEnabled = false;
    this.addVisibleSections(this._getSectionsUpTo(section));
    this.lastVisibleSection = section;

    // iOS hack to avoid blank div when requesting section during momentum
    if (this.scrollableNode && this.capabilities.isIOS) {
      this.scrollableNode.style.overflow = "hidden";
    }

    next(() => {
      schedule("afterRender", () => {
        const targetEmoji = document.querySelector(
          `.emoji-picker__section[data-section="${section}"]`
        );
        targetEmoji.scrollIntoView({ block: "nearest" });

        // iOS hack to avoid blank div when requesting section during momentum
        if (this.scrollableNode && this.capabilities.isIOS) {
          this.scrollableNode.style.overflow = "scroll";
        }

        this.scrollObserverEnabled = true;
      });
    });
  }

  @action
  async loadEmojis() {
    if (this.emojiStore.list) {
      this.didInputFilter(this.term);
      return;
    }

    this.loading = true;

    try {
      this.emojiStore.list = await ajax("/emojis.json");

      // we cant filter an empty list so have to wait for it
      this.didInputFilter(this.term);
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

      document
        .querySelector(".emoji-picker__section-btn.active")
        ?.scrollIntoView({
          block: "nearest",
          inline: "start",
        });
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

  _getSectionsUpTo(section) {
    const sections = [];
    for (const sectionNode of document.querySelectorAll(
      ".emoji-picker__section"
    )) {
      const sectionName = sectionNode.dataset.section;
      sections.push(sectionNode.dataset.section);
      if (sectionName === section) {
        break;
      }
    }
    return sections;
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    {{! template-lint-disable no-nested-interactive }}
    {{! template-lint-disable no-pointer-down-event-binding }}
    <div
      class={{concatClass "emoji-picker"}}
      {{didInsert this.loadEmojis}}
      {{didInsert (if @didInsert @didInsert (noop))}}
      {{on "keydown" this.trapKeyDownEvents}}
      ...attributes
    >
      <div class="emoji-picker__filter-container">
        <PluginOutlet
          @name="emoji-picker-filter-container"
          @outletArgs={{lazyHash
            term=this.term
            focusFilter=this.focusFilter
            registerFilterInput=this.registerFilterInput
            didInputFilter=this.didInputFilter
            context=@context
            close=@close
          }}
        >
          <FilterInput
            {{didInsert this.focusFilter}}
            {{didInsert this.registerFilterInput}}
            @value={{this.term}}
            @filterAction={{withEventValue this.didInputFilter}}
            @icons={{hash right="magnifying-glass"}}
            @containerClass="emoji-picker__filter"
            placeholder={{i18n "chat.emoji_picker.search_placeholder"}}
          />

          <DiversityMenu />

          {{#if this.site.mobileView}}
            <DButton
              @icon="xmark"
              @action={{@close}}
              class="btn-transparent emoji-picker__close-btn"
            />
          {{/if}}
        </PluginOutlet>
      </div>

      <div class="emoji-picker__content">
        <div class="emoji-picker__sections-nav" {{this.setupSectionsNavScroll}}>
          {{#each-in this.groups as |section emojis|}}
            {{#if emojis.length}}
              <DButton
                class={{concatClass
                  "btn-flat"
                  "emoji-picker__section-btn"
                  (if (eq this.lastVisibleSection section) "active")
                }}
                tabindex="-1"
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
                    src={{tonableEmojiUrl
                      (get emojis "0")
                      this.emojiStore.diversity
                    }}
                  />
                {{/if}}
              </DButton>
            {{/if}}
          {{/each-in}}
        </div>

        {{#if this.emojiStore.list}}
          <div class="emoji-picker__scrollable-content" {{this.scrollListener}}>
            <div
              class="emoji-picker__sections"
              {{on "click" this.didSelectEmoji}}
              {{on "keydown" this.onSectionsKeyDown}}
              role="button"
            >
              {{#if this.term.length}}
                <div class="emoji-picker__section filtered">
                  {{#each this.filteredEmojis as |emoji|}}
                    <img
                      width="32"
                      height="32"
                      class="emoji"
                      src={{tonableEmojiUrl emoji this.emojiStore.diversity}}
                      tabindex="0"
                      data-emoji={{emoji.name}}
                      data-tonable={{if emoji.tonable "true"}}
                      alt={{emoji.name}}
                      title={{tonableEmojiTitle
                        emoji
                        this.emojiStore.diversity
                      }}
                      loading="lazy"
                    />
                  {{else}}
                    {{#if this.isFiltering}}
                      <div class="spinner-container">
                        <div class="spinner medium"></div>
                      </div>
                    {{else}}
                      <p class="emoji-picker__no-results">
                        {{i18n "chat.emoji_picker.no_results"}}
                        {{replaceEmoji ":crying_cat_face:"}}
                      </p>
                    {{/if}}
                  {{/each}}
                </div>
              {{else}}
                {{#each-in this.groups as |section emojis|}}
                  {{#if emojis}}
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
                      <div class="emoji-picker__section-title-container">
                        <h2 class="emoji-picker__section-title">
                          {{i18n
                            (concat "chat.emoji_picker." section)
                            translatedFallback=section
                          }}
                        </h2>
                        {{#if (eq section "favorites")}}
                          <DButton
                            @icon="trash-can"
                            class="btn-transparent"
                            @action={{this.clearFavorites}}
                          />
                        {{/if}}
                      </div>
                      <div class="emoji-picker__section-emojis">
                        {{! we always want the first emoji for tabbing}}
                        {{#let (get emojis "0") as |emoji|}}
                          <img
                            width="32"
                            height="32"
                            class="emoji"
                            src={{tonableEmojiUrl
                              emoji
                              this.emojiStore.diversity
                            }}
                            tabindex="0"
                            data-emoji={{emoji.name}}
                            data-tonable={{if emoji.tonable "true"}}
                            alt={{emoji.name}}
                            title={{tonableEmojiTitle
                              emoji
                              this.emojiStore.diversity
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
                                  this.emojiStore.diversity
                                }}
                                tabindex="-1"
                                data-emoji={{emoji.name}}
                                data-tonable={{if emoji.tonable "true"}}
                                alt={{emoji.name}}
                                title={{tonableEmojiTitle
                                  emoji
                                  this.emojiStore.diversity
                                }}
                                loading="lazy"
                              />
                            {{/if}}
                          {{/each}}
                        {{/if}}
                      </div>
                    </div>
                  {{/if}}
                {{/each-in}}
              {{/if}}
            </div>
          </div>
        {{else}}
          <div class="spinner-container">
            <div class="spinner medium"></div>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
