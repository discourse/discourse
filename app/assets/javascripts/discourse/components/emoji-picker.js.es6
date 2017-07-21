import { observes } from "ember-addons/ember-computed-decorators";
import { findRawTemplate } from "discourse/lib/raw-templates";
import { emojiUrlFor } from "discourse/lib/text";
import KeyValueStore from "discourse/lib/key-value-store";
import { emojis } from "pretty-text/emoji/data";
import { extendedEmojiList, isSkinTonableEmoji } from "pretty-text/emoji";

const keyValueStore = new KeyValueStore("discourse_emojis_");
const EMOJI_USAGE = "emojiUsage";
const EMOJI_SCROLL_Y = "emojiScrollY";
const EMOJI_SELECTED_DIVERSITY = "emojiSelectedDiversity";
const EMOJI_CACHED_SECTIONS = "emojiCachedSections";
const PER_ROW = 11;
const customEmojis = _.map(_.keys(extendedEmojiList()), code => {
  return { code, src: emojiUrlFor(code) };
});

export function resetCache() {
  keyValueStore.setObject({ key: EMOJI_CACHED_SECTIONS, value: [] });
  keyValueStore.setObject({ key: EMOJI_USAGE, value: [] });
  keyValueStore.setObject({ key: EMOJI_SCROLL_Y, value: 0 });
  keyValueStore.setObject({ key: EMOJI_SELECTED_DIVERSITY, value: 1 });
}

let $picker, $filter, $results, $list;

export default Ember.Component.extend({
  willDestroyElement() {
    this._super();

    this._unbindEvents();
    this.appEvents.off("emoji-picker:close");
  },

  didDestroyElement() {
    this._super();

    $picker = null;
  },

  didInsertElement() {
    this._super();

    this.appEvents.on("emoji-picker:close", () => this.set("active", false));

    $picker = this.$(".emoji-picker");

    if (!keyValueStore.getObject(EMOJI_CACHED_SECTIONS)) {
      keyValueStore.setObject({ key: EMOJI_CACHED_SECTIONS, value: [] });
    }

    if (!keyValueStore.getObject(EMOJI_USAGE)) {
      keyValueStore.setObject({ key: EMOJI_USAGE, value: [] });
    } else if(_.isPlainObject(keyValueStore.getObject(EMOJI_USAGE))) {
      // handle legacy format
      keyValueStore.setObject({ key: EMOJI_USAGE, value: _.keys(keyValueStore.getObject(EMOJI_USAGE)) });
    }
  },

  didUpdateAttrs() {
    this._super();

    if (this.get("active")) {
      this.show();
    } else {
      this.close();
    }
  },

  @observes("filter")
  filterChanged() {
    $filter.find(".clear-filter").toggle(!_.isEmpty(this.get("filter")));
    Ember.run.debounce(this, this._filterEmojisList, 250);
  },

  @observes("selectedDiversity")
  selectedDiversityChanged() {
    keyValueStore.setObject({key: EMOJI_SELECTED_DIVERSITY, value: this.get("selectedDiversity")});

    $.each($list.find(".emoji.diversity[src!='']"), (_, icon) => this._setIconSrc(icon, true) );

    if(this.get("filter") !== "") {
      $.each($results.find(".emoji.diversity"), (_, icon) => this._setIconSrc(icon, true) );
    }
  },

  @observes("recentEmojis")
  recentEmojisChanged() {
    const $recentSection = $list.find(".section[data-section='recent']");
    const $recentSectionGroup = $recentSection.find(".section-group");
    const $recentCategory = $picker.find(".category-icon a[title='recent']").parent();

    // we set height to 0 to avoid it being taken into account for scroll position
    if(_.isEmpty(this.get("recentEmojis"))) {
      $recentCategory.hide();
      $recentSection.css("height", 0).hide();
    } else {
      $recentCategory.show();
      $recentSection.css("height", "auto").show();
    }

    const recentEmojis = _.map(this.get("recentEmojis"), code => {
      return { code, src: emojiUrlFor(code) };
    });
    const model = { recentEmojis };
    const template = findRawTemplate("emoji-picker-recent")(model);
    $recentSectionGroup.html(template);
    this._bindHover($recentSectionGroup);
  },

  close() {
    $picker
      .css({width: "", left: "", bottom: "", display: "none"})
      .empty();

    this.$().find(".emoji-picker-modal").remove();

    this._unbindEvents();
  },

  show() {
    const template = findRawTemplate("emoji-picker")({ customEmojis });
    $picker.html(template);
    this.$().append("<div class='emoji-picker-modal'></div>");

    $filter = $picker.find(".filter");
    $results = $picker.find(".results");
    $list = $picker.find(".list");

    this.set("selectedDiversity", keyValueStore.getObject(EMOJI_SELECTED_DIVERSITY) || 1);
    this.set("recentEmojis", keyValueStore.getObject(EMOJI_USAGE) || []);

    this._bindEvents();

    Ember.run.scheduleOnce("afterRender", this, function() {
      this._setDiversity();
      this._positionPicker();
      this._scrollTo();
    });
  },

  _bindEvents() {
    this._bindDiversityClick();
    this._bindSectionsScroll();
    this._bindEmojiClick($list.find(".section-group"));
    this._bindClearRecentEmojisGroup();
    this._bindResizing();
    this._bindCategoryClick();
    this._bindModalClick();
    this._bindFilterInput();

    if(!this.site.isMobileDevice) {
      this._bindHover();
    }
  },

  _bindModalClick() {
    this.$(".emoji-picker-modal")
        .on("click", () => this.set("active", false));

    this.$(document).on("click.emoji-picker", (event) => {
      const onPicker = $(event.target).parents(".emoji-picker").length === 1;
      const onGrippie = event.target.className.indexOf("grippie") > -1;
      if(!onPicker && !onGrippie) {
        this.set("active", false);
        return false;
      }
    });
  },

  _unbindEvents() {
    this.$(window).off("resize");
    this.$(".emoji-picker-modal").off("click");
    Ember.$("#reply-control").off("div-resizing");
    this.$(document).off("click.emoji-picker");
  },

  _filterEmojisList() {
    if (this.get("filter") === "") {
      $filter.find("input[name='filter']").val("");
      $results.empty().hide();
      $list.show();
    } else {
      const regexp = new RegExp(this.get("filter"), "g");
      const filteredCodes = _.filter(emojis, code => regexp.test(code)).slice(0, 30);
      $results.empty().html(
        _.map(filteredCodes, (code) => {
          const hasDiversity = isSkinTonableEmoji(code);
          const diversity = hasDiversity ? "diversity" : "";
          const scaledCode = this._codeWithDiversity(code, hasDiversity);
          return `<a title="${code}">
                    <img src="${emojiUrlFor(scaledCode)}" data-code="${code}" class="emoji ${diversity}" />
                  </a>`;
        })
      ).show();
      this._bindHover($results);
      this._bindEmojiClick($results);
      $list.hide();
    }
  },

  _bindFilterInput() {
    const $input = $filter.find("input");

    $input.on("input", (event) => {
      this.set("filter", event.currentTarget.value);
    });

    $filter.find(".clear-filter").on("click", () => {
      $input.val("").focus();
      this.set("filter", "");
      return false;
    });
  },

  _bindCategoryClick() {
    $picker.find(".category-icon").on("click", "a", (event) => {
      this.set("filter", "");
      $results.empty();
      $list.show();

      const section = $(event.currentTarget).attr("title");
      const $section = $list.find(`.section[data-section="${section}"]`);
      const scrollTop = $list.scrollTop() + ($section.offset().top - $list.offset().top);

      this._scrollTo(scrollTop);
      return false;
    });
  },

  _bindHover($hoverables) {
    const replaceInfoContent = (html) => $picker.find(".footer .info").html(html || "");

    ($hoverables || $list.find(".section-group")).on({
      mouseover: (event) => {
        const code = this._codeForEmojiLink($(event.currentTarget));
        const html = `<img src="${emojiUrlFor(code)}" class="emoji"> <span>:${code}:<span>`;
        replaceInfoContent(html);
      },
      mouseleave: () => replaceInfoContent()
    }, "a");
  },

  _bindResizing() {
    this.$(window).on("resize", () => {
      Ember.run.throttle(this, this._positionPicker, 16);
    });

    Ember.$("#reply-control").on("div-resizing", () => {
      Ember.run.throttle(this, this._positionPicker, 16);
    });
  },

  _bindClearRecentEmojisGroup() {
    const $recent = $picker.find(".section[data-section='recent'] .clear-recent");
    $recent.on("click", () => {
      keyValueStore.setObject({ key: EMOJI_USAGE, value: [] });
      this.set("recentEmojis", []);
      this._scrollTo(0);
      return false;
    });
  },

  _bindEmojiClick($emojisContainer) {
    const handler = (event) => {
      const code = this._codeForEmojiLink($(event.currentTarget));

      if($(event.currentTarget).parents(".section[data-section='recent']").length === 0) {
        this._trackEmojiUsage(code);
      }

      this.sendAction("emojiSelected", code);

      if(this.$(".emoji-picker-modal").hasClass("fadeIn")) {
        this.set("active", false);
      }

      return false;
    };

    if(this.site.isMobileDevice) {
      const self = this;

      $emojisContainer
        .off("touchstart")
        .on("touchstart", "a", (touchStartEvent) => {
          const $this = $(touchStartEvent.currentTarget);
          $this.on("touchend", (touchEndEvent) => {
            handler.bind(self)(touchEndEvent);
            $this.off("touchend");
          });
          $this.on("touchmove", () => $this.off("touchend") );
        });
    } else {
      $emojisContainer.off("click").on("click", "a", e => handler.bind(this)(e) );
    }
  },

  _bindSectionsScroll() {
    $list.on("scroll", () => {
      Ember.run.debounce(this, this._checkVisibleSection, 150);
      Ember.run.debounce(this, this._storeScrollPosition, 100);
    });
  },

  _checkVisibleSection() {
    // make sure we stop loading if picker has been removed
    if(!$picker) {
      return;
    }

    const $sections = $list.find(".section");
    const sections = [];
    let cumulatedHeight = 0;

    $.each($sections, (_, section) => {
      const $section = $(section);
      sections.push({$section, cumulatedHeight});
      cumulatedHeight += $section.innerHeight();
    });

    let selectedSection;
    const currentScrollTop = $list.scrollTop();
    if (!_.isEmpty(this.get("recentEmojis")) && currentScrollTop === 0) {
      selectedSection = _.first(sections);
    } else if (!_.isEmpty(customEmojis) &&
               currentScrollTop === $list[0].scrollHeight - $list.innerHeight())
    {
      selectedSection = _.last(sections);
    } else {
      selectedSection = _.last(_.reject(sections, (section) => {
        return section.cumulatedHeight > currentScrollTop;
      }));
    }

    if(selectedSection) {
      const sectionTitle = selectedSection.$section.data("section");
      $picker.find(".category-icon").removeClass("current");
      $picker.find(`.category-icon a[title='${sectionTitle}']`)
             .parent()
             .addClass("current");

      if(!selectedSection.$section.hasClass("loaded")) {
        selectedSection.$section.addClass("loaded");
        this._loadSection(selectedSection.$section);
      }

      //preload surrounding sections
      const selectedSectionIndex = sections.indexOf(selectedSection);
      const preloadedSection = sections[selectedSectionIndex + 1] || sections[selectedSectionIndex - 1];
      if(preloadedSection && !preloadedSection.$section.hasClass("loaded")) {
        preloadedSection.$section.addClass("loaded");
        this._loadSection(preloadedSection.$section);
      }
    }
  },

  _bindDiversityClick() {
    const $diversityScales = $picker.find(".diversity-picker .diversity-scale");
    $diversityScales.on("click", (event) => {
      const $selectedDiversity = $(event.currentTarget);
      $diversityScales.removeClass("selected");
      $selectedDiversity.addClass("selected");
      this.set("selectedDiversity", parseInt($selectedDiversity.data("level")));
      return false;
    });
  },

  _setDiversity() {
    $picker
      .find(`.diversity-picker .diversity-scale[data-level="${this.get("selectedDiversity")}"]`)
      .addClass("selected");
  },

  _isReplyControlExpanded() {
    const verticalSpace = this.$(window).height() -
                          Ember.$(".d-header").height() -
                          Ember.$("#reply-control").height();

    return verticalSpace < $picker.height() - 48;
  },

  _positionPicker(){
    if(!this.get("active")) { return; }

    let windowWidth = this.$(window).width();

    const desktopModalePositioning = options => {
      let attributes = {
        width: Math.min(windowWidth, 400) - 12,
        marginLeft: -(Math.min(windowWidth, 400)/2) + 6,
        marginTop: -130,
        left: "50%",
        bottom: "",
        top: "50%",
        display: "flex"
      };

      this.$(".emoji-picker-modal").addClass("fadeIn");
      $picker.css(_.merge(attributes, options));
    };

    const mobilePositioning = options => {
      let attributes = {
        width: windowWidth - 12,
        marginLeft: 5,
        marginTop: -130,
        left: 0,
        bottom: "",
        top: "50%",
        display: "flex"
      };

      this.$(".emoji-picker-modal").addClass("fadeIn");
      $picker.css(_.merge(attributes, options));
    };

    const desktopPositioning = options => {
      let attributes = {
        width: windowWidth < 485 ? windowWidth - 12 : 400,
        marginLeft: "",
        marginTop: "",
        right: "",
        left: "",
        bottom: 32,
        top: "",
        display:
        "flex"
      };

      this.$(".emoji-picker-modal").removeClass("fadeIn");
      $picker.css(_.merge(attributes, options));
    };

    if(Ember.testing) {
      desktopPositioning();
      return;
    }

    if(this.site.isMobileDevice) {
      mobilePositioning();
    } else {
      if(this._isReplyControlExpanded()) {
        let $editorWrapper = Ember.$(".d-editor-preview-wrapper");
        if(($editorWrapper.is(":visible") && $editorWrapper.width() < 400) || windowWidth < 485) {
          desktopModalePositioning();
        } else {
          if($editorWrapper.is(":visible")) {
            let previewOffset = Ember.$(".d-editor-preview-wrapper").offset();
            let replyControlOffset = Ember.$("#reply-control").offset();
            let left = previewOffset.left - replyControlOffset.left;
            desktopPositioning({left});
          } else {
            desktopPositioning({
              right: (Ember.$("#reply-control").width() - Ember.$(".d-editor-container").width()) / 2
            });
          }
        }
      } else {
        if(windowWidth < 485) {
          desktopModalePositioning();
        } else {
          let previewInputOffset = Ember.$(".d-editor-input").offset();
          let replyControlOffset = Ember.$("#reply-control").offset() || {left: 0};
          let left = previewInputOffset.left - replyControlOffset.left;
          desktopPositioning({left, bottom: Ember.$("#reply-control").height() - 48});
        }
      }
    }

    const infoMaxWidth = $picker.width() -
                         $picker.find(".categories-column").width() -
                         $picker.find(".diversity-picker").width() -
                         32;
    $picker.find(".info").css("max-width", infoMaxWidth);
  },

  _loadSection($section) {
    const sectionName = $section.data("section");
    if(keyValueStore.getObject(EMOJI_CACHED_SECTIONS).indexOf(sectionName) > -1) {
      $.each($section.find(".emoji[src='']"), (_, icon) => this._setIconSrc(icon) );
    } else {
      Ember.run.later(
        this, () => {
          keyValueStore.setObject({
            key: EMOJI_CACHED_SECTIONS,
            value: keyValueStore.getObject(EMOJI_CACHED_SECTIONS).concat(sectionName)
          });
          $.each($section.find(".emoji[src='']"), (_, icon) => this._setIconSrc(icon) );
        },
        1500
      );
    }
  },

  _codeWithDiversity(code, diversity) {
    if(diversity && this.get("selectedDiversity") !== 1) {
      return `${code}:t${this.get("selectedDiversity")}`;
    } else {
      return code;
    }
  },

  _storeScrollPosition() {
    keyValueStore.setObject({
      key: EMOJI_SCROLL_Y,
      value: $list.scrollTop()
    });
  },

  _trackEmojiUsage(code) {
    let recent = keyValueStore.getObject(EMOJI_USAGE) || [];
    recent = recent.filter(r => r !== code);
    recent.unshift(code);
    recent.length = Math.min(recent.length, PER_ROW);
    keyValueStore.setObject({ key: EMOJI_USAGE, value: recent });
    this.set("recentEmojis", recent);
  },

  _scrollTo(y) {
    const yPosition = _.isUndefined(y) ? keyValueStore.getObject(EMOJI_SCROLL_Y) : y;

    $list.scrollTop(yPosition);

    // if we don’t actually scroll we need to force it
    if(yPosition === 0) {
      $list.scroll();
    }
  },

  _codeForEmojiLink($a) {
    const title = $a.attr("title");
    const $img = $a.find("img");
    return this._codeWithDiversity(title, $img.hasClass("diversity"));
  },

  _setIconSrc(icon, diversity) {
    const $icon = $(icon);
    const code = this._codeWithDiversity(
      $icon.parent().attr("title"),
      diversity || $icon.hasClass("diversity")
    );

    // force visual reloading if needed
    if($icon.attr("src") !== "") {
      $icon.attr("src", "");
    }

    $icon.attr("src", emojiUrlFor(code));
  },
});
