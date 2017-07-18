import { observes } from "ember-addons/ember-computed-decorators";
import { findRawTemplate } from "discourse/lib/raw-templates";
import { emojiUrlFor } from "discourse/lib/text";
import KeyValueStore from "discourse/lib/key-value-store";
import { emojis } from "pretty-text/emoji/data";
import { extendedEmojiList, isSkinTonableEmoji } from "pretty-text/emoji";

const recentTemplate = findRawTemplate("emoji-picker-recent");
const pickerTemplate = findRawTemplate("emoji-picker");
export const keyValueStore = new KeyValueStore("discourse_emojis_");
export const EMOJI_USAGE = "emojiUsage";
export const EMOJI_SCROLL_Y = "emojiScrollY";
export const EMOJI_SELECTED_DIVERSITY = "emojiSelectedDiversity";
const PER_ROW = 11;

export default Ember.Component.extend({
  customEmojis: _.map(_.keys(extendedEmojiList()), function(code) {
    return { code, src: emojiUrlFor(code) };
  }),

  $picker: Ember.computed("active", function() {
    return this.$(".emoji-picker");
  }),

  $filter: Ember.computed("$picker", function() {
    return this.get("$picker").find(".filter");
  }),

  $results: Ember.computed("$picker", function() {
    return this.get("$picker").find(".results");
  }),

  $list: Ember.computed("$picker", function() {
    return this.get("$picker").find(".list");
  }),

  willDestroyElement() {
    this._super();
    this._unbindEvents();
  },

  didInsertElement() {
    this._super();

    if (!keyValueStore.getObject(EMOJI_USAGE)) {
      keyValueStore.setObject({ key: EMOJI_USAGE, value: {} });
    }

    this.set("selectedDiversity", keyValueStore.getObject(EMOJI_SELECTED_DIVERSITY) || 1);
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
    this.get("$filter").find(".clear-filter").toggle(!_.isEmpty(this.get("filter")));
    Ember.run.debounce(this, this._filterEmojisList, 250);
  },

  @observes("selectedDiversity")
  selectedDiversityChanged() {
    keyValueStore.setObject({key: EMOJI_SELECTED_DIVERSITY, value: this.get("selectedDiversity")});

    $.each(this.get("$list").find(".emoji.diversity[src!='']"), (_, icon) => {
      this._updateIconSrc(icon);
    });

    if(this.get("filter") !== "") {
      $.each(this.get("$results").find(".emoji.diversity"), (_, icon) => {
        this._updateIconSrc(icon);
      });
    }
  },

  @observes("recentEmojis")
  recentEmojisChanged() {
    const $recentSection = this.get("$list").find(".section[data-section='recent']");
    const $recentSectionGroup = $recentSection.find(".section-group");
    const $recentCategory = this.get("$picker").find(".category-icon a[title='recent']").parent();
    if(_.isEmpty(this.get("recentEmojis"))) {
      $recentCategory.hide();
      $recentSection.css("height", 0).hide();
    } else {
      $recentCategory.show();
      $recentSection.css("height", "auto").show();
    }

    const recentEmojis = _.map(this.get("recentEmojis"), function(emoji) {
      return { code: emoji.title, src: emojiUrlFor(emoji.title) };
    });
    const model = { recentEmojis };
    const template = recentTemplate(model);
    $recentSectionGroup.html(template);
    this._bindHover($recentSectionGroup.find("a"));
  },

  close() {
    this.get("$picker")
      .css({width: "", left: "", bottom: ""})
      .empty();
    this.$(".emoji-picker-modal").removeClass("fadeIn");

    this._unbindEvents();
  },

  show() {
    const model = { customEmojis: this.get("customEmojis") };
    const template = pickerTemplate(model);
    this.get("$picker").html(template);

    this._bindEvents();

    Ember.run.later(this, function() {
      this._setDiversity();
      this._positionPicker();
      this._scrollTo();
      this.recentEmojisChanged();
    });
  },

  _bindEvents() {
    this._bindDiversityClick();
    this._bindSectionsScroll();
    this._bindEmojiClick();
    this._bindClearRecentEmojisGroup();
    this._bindResizing();
    this._bindHover();
    this._bindCategoryClick();
    this._bindModalClick();
    this._bindFilterInput();
    this._bindEscape();
  },

  _bindEscape() {
    this.$().on("keydown", e => {
      if (e.which === 27) {
        this.set("active", false);
        return false;
      }
    });
  },

  _bindModalClick() {
    this.$(".emoji-picker-modal").on("click", () => {
      this.set("active", false);
    });
  },

  _unbindEvents() {
    this.$(window).off("resize");
    this.$(".emoji-picker-modal").off("click");
    Ember.$("#reply-control").off("div-resized");
    this.$().off("keydown");
  },

  _filterEmojisList() {
    const $filter = this.get("$picker").find(".filter");

    if (this.get("filter") === "") {
      $filter.find("input[name='filter']").val("");
      this.get("$results").empty().hide();
      this.get("$list").show();
    } else {
      const regexp = new RegExp(this.get("filter"), "g");
      const filteredCodes = _.filter(emojis, code => regexp.test(code)).slice(0, 30);
      this.get("$results").empty().html(
        _.map(filteredCodes, (code) => {
          const hasDiversity = isSkinTonableEmoji(code);
          const diversity = hasDiversity ? "diversity" : "";
          const scaledCode = this._codeWithDiversity(code, hasDiversity);
          return `<a title="${code}">
                    <img src="${emojiUrlFor(scaledCode)}" data-code="${code}" class="emoji ${diversity}" />
                  </a>`;
        })
      ).show();
      this._bindHover(this.get("$results").find("a"));
      this._bindEmojiClick(this.get("$results"));
      this.get("$list").hide();
    }
  },

  _bindFilterInput() {
    const $filter = this.get("$picker").find(".filter");
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
    this.get("$picker").find(".category-icon").on("click", "a", (event) => {
      this.set("filter", "");
      this.get("$results").empty();
      this.get("$list").show();

      const section = $(event.currentTarget).attr("title");
      const $section = this.get("$list").find(`.section[data-section="${section}"]`);
      const scrollTop = this.get("$list").scrollTop() +
                        ( $section.offset().top - this.get("$list").offset().top );

      this._scrollTo(scrollTop);
      return false;
    });
  },

  _bindHover(hoverables) {
    const replaceInfoContent = (html) => {
      this.get("$picker").find(".footer .info").html(html || "");
    };

    (hoverables || this.$(".section-group a")).hover(event => {
        const $a = $(event.currentTarget);
        const code = this._codeWithDiversity($a.attr("title"), $a.find("img").hasClass("diversity"));
        const html = `<img src="${emojiUrlFor(code)}" class="emoji"> <span>:${code}:<span>`;
        replaceInfoContent(html);
      },
      () => replaceInfoContent()
    );
  },

  _bindResizing() {
    this.$(window).on("resize", () => {
      Ember.run.debounce(this, this._positionPicker, 100);
    });

    Ember.$("#reply-control").on("div-resized", () => {
      Ember.run.debounce(this, this._positionPicker, 100);
    });
  },

  _bindClearRecentEmojisGroup() {
    const $recent = this.get("$picker").find(".section[data-section='recent'] .clear-recent");
    $recent.on("click", () => {
      keyValueStore.setObject({ key: EMOJI_USAGE, value: {} });
      this.set("recentEmojis", {});
      this._scrollTo(0);
      return false;
    });
  },

  _bindEmojiClick(emojisContainer) {
    const $emojisContainer = emojisContainer || this.get("$list").find(".section-group");
    $emojisContainer.off("click").on("click", "a", e => {
      const $icon = $(e.currentTarget);
      const title = $icon.attr("title");
      const code = this._codeWithDiversity(title, $icon.find("img").hasClass("diversity"));

      this._trackEmojiUsage(code);

      if(this._isSmallViewport()) {
        this.set("active", false);
      }

      return false;
    });
  },

  _bindSectionsScroll() {
    this.get("$list").on("scroll", () => {
      Ember.run.debounce(this, this._checkVisibleSection, 150);
      Ember.run.debounce(this, this._storeScrollPosition, 50);
    });
  },

  _checkVisibleSection() {
    const $sections = this.get("$list").find(".section");
    const sections = [];
    let cumulatedHeight = 0;

    $.each($sections, (_, section) => {
      const $section = $(section);
      sections.push({$section, cumulatedHeight});
      cumulatedHeight += $section.innerHeight();
    });

    let selectedSection;
    const currentScrollTop = this.get("$list").scrollTop();
    if (!_.isEmpty(this.get("recentEmojis")) && currentScrollTop === 0) {
      selectedSection = _.first(sections);
    } else if (!_.isEmpty(this.get("customEmojis")) &&
               currentScrollTop === this.get("$list")[0].scrollHeight - this.get("$list").innerHeight())
    {
      selectedSection = _.last(sections);
    } else {
      selectedSection = _.last(_.reject(sections, (section) => {
        return section.cumulatedHeight > currentScrollTop;
      }));
    }

    if(selectedSection) {
      this.get("$picker").find(".category-icon").removeClass("current");
      this.get("$picker").find(`.category-icon a[title='${selectedSection.$section.data("section")}']`)
                         .parent()
                         .addClass("current");

      if(!selectedSection.$section.hasClass("loaded")) {
        selectedSection.$section.addClass("loaded");
        this._loadVisibleEmojis(selectedSection.$section.find(".emoji[src='']"));
      }

      //preload surrounding sections
      const selectedSectionIndex = sections.indexOf(selectedSection);
      const preloadedSection = sections[selectedSectionIndex + 1] || sections[selectedSectionIndex - 1];
      if(preloadedSection && !preloadedSection.$section.hasClass("loaded")) {
        preloadedSection.$section.addClass("loaded");
        const $visibleEmojis = preloadedSection.$section.find(".emoji[src='']");
        Ember.run.later(() => { this._loadVisibleEmojis($visibleEmojis); }, 1500);
      }
    }
  },

  _bindDiversityClick() {
    const $diversityScales = this.get("$picker").find(".diversity-picker .diversity-scale");
    $diversityScales.on("click", (event) => {
      const $selectedDiversity = $(event.currentTarget);
      $diversityScales.removeClass("selected");
      $selectedDiversity.addClass("selected");
      this.set("selectedDiversity", parseInt($selectedDiversity.data("level")));
      return false;
    });
  },

  _setDiversity() {
    this.get("$picker")
      .find(`.diversity-picker .diversity-scale[data-level="${this.get("selectedDiversity")}"]`)
      .addClass("selected");
  },

  _isSmallViewport() {
    return this.site.isMobileDevice || this.$(window).width() <= 1024 || this.$(window).height() <= 768;
  },

  _positionPicker(){
    if(!this.get("active")) { return; }

    let isLargePreview = this.$(window).height() -
                         Ember.$(".d-header").height() -
                         Ember.$("#reply-control").height() <
                         this.get("$picker").height() + 16;

    if(this._isSmallViewport()) {
      this.$(".emoji-picker-modal").addClass("fadeIn");
      this.get("$picker").css({
        width: this.site.isMobileDevice ? this.$(window).width() - 10 : 340,
        marginLeft: this.site.isMobileDevice ? -(this.$(window).width() - 10)/2 : -170,
        marginTop: -150,
        left: "50%",
        top: "50%"
      });
    } else {
      this.$(".emoji-picker-modal").removeClass("fadeIn");

      let cssAttributes = { width: 400, marginLeft: "", marginTop: "", left: "", top: "" };
      if(isLargePreview) {
        cssAttributes.left = (Ember.$("#reply-control").width() - Ember.$(".d-editor").width() ) / 2 + Ember.$(".d-editor-preview-wrapper").position().left;
        cssAttributes.bottom = 32;
      } else {
        cssAttributes.left = (Ember.$("#reply-control").width() - Ember.$(".d-editor").width() ) / 2 + Ember.$(".d-editor").position().left;
        cssAttributes.bottom = Ember.$("#reply-control").height() - 48;
      }

      this.get("$picker").css(cssAttributes);
    }

    const infoMaxWidth = this.get("$picker").width() -
                         this.get("$picker").find(".categories-column").width() -
                         this.get("$picker").find(".diversity-picker").width() -
                         32;
    this.get("$picker").find(".info").css("max-width", infoMaxWidth);
  },

  _loadVisibleEmojis($visibleEmojis) {
    $.each($visibleEmojis, (_, icon) => {
      const $icon = $(icon);
      const code = this._codeWithDiversity($icon.parents("a").attr("title"), $icon.hasClass("diversity"));
      $icon.attr("src", emojiUrlFor(code));
    });
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
      value: this.get("$list").scrollTop()
    });
  },

  _trackEmojiUsage(code) {
    const recent = keyValueStore.getObject(EMOJI_USAGE) || {};

    if (!recent[code]) {
      // keeping title here for legacy reasons, might migrate later
      recent[code] = { title: code, usage: 0 };
    }
    recent[code]["usage"]++;

    keyValueStore.setObject({ key: EMOJI_USAGE, value: recent });

    this.set("recentEmojis", _.map(recent).sort(this._sortByUsage).slice(0, PER_ROW));

    this.sendAction("emojiSelected", code);
  },

  _sortByUsage(a, b) {
    if (a.usage > b.usage) { return -1; }
    if (b.usage > a.usage) { return 1; }
    return a.title.localeCompare(b.title);
  },

  _scrollTo(y) {
    const yPosition = _.isUndefined(y) ? keyValueStore.getObject(EMOJI_SCROLL_Y) : y;

    this.get("$list").scrollTop(yPosition);

    // if we don’t actually scroll we need to force it
    if(yPosition === 0) {
      this.get("$list").scroll();
    }
  },

  _updateIconSrc(icon) {
    const $icon = $(icon);
    const code = this._codeWithDiversity($icon.parents("a").attr("title"), true);
    $icon.attr("src", emojiUrlFor(code));
  },
});
