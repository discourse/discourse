import { inject as service } from '@ember/service';
import Component from "@ember/component";
import { on, observes } from "ember-addons/ember-computed-decorators";
import { findRawTemplate } from "discourse/lib/raw-templates";
import { emojiUrlFor } from "discourse/lib/text";

import {
  extendedEmojiList,
  isSkinTonableEmoji,
  emojiSearch
} from "pretty-text/emoji";
import { safariHacksDisabled } from "discourse/lib/utilities";
const { run } = Ember;

const PER_ROW = 11;
const customEmojis = _.keys(extendedEmojiList()).map(code => {
  return { code, src: emojiUrlFor(code) };
});

export default Component.extend({
  automaticPositioning: true,
  emojiStore: service("emoji-store"),

  close() {
    this._unbindEvents();

    this.$picker
      .css({ width: "", left: "", bottom: "", display: "none" })
      .empty();

    this.$modal.removeClass("fadeIn");

    clearTimeout(this._checkTimeout);
  },

  show() {
    const template = findRawTemplate("emoji-picker")({ customEmojis });
    this.$picker.html(template);

    this.$filter = this.$picker.find(".filter");
    this.$results = this.$picker.find(".results");
    this.$list = this.$picker.find(".list");

    this.setProperties({
      selectedDiversity: this.emojiStore.diversity,
      recentEmojis: this.emojiStore.favorites
    });

    run.scheduleOnce("afterRender", this, function() {
      this._bindEvents();
      this._loadCategoriesEmojis();
      this._positionPicker();
      this._scrollTo();
      this._updateSelectedDiversity();
      this._checkVisibleSection(true);

      if (
        (!this.site.isMobileDevice || this.isEditorFocused) &&
        !safariHacksDisabled()
      )
        this.$filter.find("input[name='filter']").focus();
    });
  },

  @on("init")
  _setInitialValues() {
    this._checkTimeout = null;
    this.scrollPosition = 0;
    this.$visibleSections = [];
  },

  @on("willDestroyElement")
  _unbindGlobalEvents() {
    this.appEvents.off("emoji-picker:close", this, "_closeEmojiPicker");
  },

  _closeEmojiPicker() {
    this.set("active", false);
  },

  @on("didInsertElement")
  _setup() {
    this.$picker = $(this.element.querySelector(".emoji-picker"));
    this.$modal = $(this.element.querySelector(".emoji-picker-modal"));
    this.appEvents.on("emoji-picker:close", this, "_closeEmojiPicker");
  },

  @on("didUpdateAttrs")
  _setState() {
    this.active ? this.show() : this.close();
  },

  @observes("filter")
  filterChanged() {
    this.$filter.find(".clear-filter").toggle(!_.isEmpty(this.filter));
    const filterDelay = this.site.isMobileDevice ? 400 : 250;
    run.debounce(this, this._filterEmojisList, filterDelay);
  },

  @observes("selectedDiversity")
  selectedDiversityChanged() {
    this.emojiStore.diversity = this.selectedDiversity;

    $.each(
      this.$list.find(".emoji[data-loaded='1'].diversity"),
      (_, button) => {
        $(button)
          .css("background-image", "")
          .removeAttr("data-loaded");
      }
    );

    if (this.filter !== "") {
      $.each(this.$results.find(".emoji.diversity"), (_, button) =>
        this._setButtonBackground(button, true)
      );
    }

    this._updateSelectedDiversity();
    this._checkVisibleSection(true);
  },

  @observes("recentEmojis")
  _recentEmojisChanged() {
    const previousScrollTop = this.scrollPosition;
    const $recentSection = this.$list.find(".section[data-section='recent']");
    const $recentSectionGroup = $recentSection.find(".section-group");
    const $recentCategory = this.$picker
      .find(".category-icon button[data-section='recent']")
      .parent();
    let persistScrollPosition = !$recentCategory.is(":visible") ? true : false;

    // we set height to 0 to avoid it being taken into account for scroll position
    if (_.isEmpty(this.recentEmojis)) {
      $recentCategory.hide();
      $recentSection.css("height", 0).hide();
    } else {
      $recentCategory.show();
      $recentSection.css("height", "auto").show();
    }

    const recentEmojis = this.recentEmojis.map(code => {
      return { code, src: emojiUrlFor(code) };
    });
    const template = findRawTemplate("emoji-picker-recent")({ recentEmojis });
    $recentSectionGroup.html(template);

    if (persistScrollPosition) {
      this.$list.scrollTop(previousScrollTop + $recentSection.outerHeight());
    }

    this._bindHover($recentSectionGroup);
  },

  _updateSelectedDiversity() {
    const $diversityPicker = this.$picker.find(".diversity-picker");

    $diversityPicker.find(".diversity-scale").removeClass("selected");
    $diversityPicker
      .find(`.diversity-scale[data-level="${this.selectedDiversity}"]`)
      .addClass("selected");
  },

  _loadCategoriesEmojis() {
    $.each(
      this.$picker.find(".categories-column button.emoji"),
      (_, button) => {
        const $button = $(button);
        const code = this._codeWithDiversity($button.data("tabicon"), false);
        $button.css("background-image", `url("${emojiUrlFor(code)}")`);
      }
    );
  },

  _bindEvents() {
    this._bindDiversityClick();
    this._bindSectionsScroll();
    this._bindEmojiClick(this.$list.find(".section-group"));
    this._bindClearRecentEmojisGroup();
    this._bindResizing();
    this._bindCategoryClick();
    this._bindModalClick();
    this._bindFilterInput();

    if (!this.site.isMobileDevice) {
      this._bindHover();
    }
  },

  _bindModalClick() {
    this.$modal.on("click", () => this.set("active", false));

    $("html").on("mouseup.emoji-picker", event => {
      let $target = $(event.target);
      if (
        $target.closest(".emoji-picker").length ||
        $target.closest(".emoji.btn").length ||
        $target.hasClass("grippie")
      ) {
        return;
      }

      // Close the popup if clicked outside
      this.set("active", false);
      return false;
    });
  },

  @on("willDestroyElement")
  _unbindEvents() {
    $(this.element).off();
    $(window).off("resize");
    clearInterval(this._refreshInterval);
    $("#reply-control").off("div-resizing");
    $("html").off("mouseup.emoji-picker");
  },

  _filterEmojisList() {
    if (this.filter === "") {
      this.$filter.find("input[name='filter']").val("");
      this.$results.empty().hide();
      this.$list.css("visibility", "visible");
    } else {
      const lowerCaseFilter = this.filter.toLowerCase();
      const filteredCodes = emojiSearch(lowerCaseFilter, { maxResults: 30 });
      this.$results
        .empty()
        .html(
          filteredCodes.map(code => {
            const hasDiversity = isSkinTonableEmoji(code);
            const diversity = hasDiversity ? "diversity" : "";
            const scaledCode = this._codeWithDiversity(code, hasDiversity);
            return `<button style="background-image: url('${emojiUrlFor(
              scaledCode
            )}')" type="button" class="emoji ${diversity}" tabindex="-1" title="${code}"></button>`;
          })
        )
        .show();
      this._bindHover(this.$results);
      this._bindEmojiClick(this.$results);
      this.$list.css("visibility", "hidden");
    }
  },

  _bindFilterInput() {
    const $input = this.$filter.find("input");

    $input.on("input", event => {
      this.set("filter", event.currentTarget.value);
    });

    this.$filter.find(".clear-filter").on("click", () => {
      $input.val("").focus();
      this.set("filter", "");
      return false;
    });
  },

  _bindCategoryClick() {
    this.$picker.find(".category-icon").on("click", "button.emoji", event => {
      this.set("filter", "");
      this.$results.empty();
      this.$list.css("visibility", "visible");

      const section = $(event.currentTarget).data("section");
      const $section = this.$list.find(`.section[data-section="${section}"]`);
      const scrollTop =
        this.$list.scrollTop() +
        ($section.offset().top - this.$list.offset().top);
      this._scrollTo(scrollTop);
      return false;
    });
  },

  _bindHover($hoverables) {
    const replaceInfoContent = html =>
      this.$picker.find(".footer .info").html(html || "");

    ($hoverables || this.$list.find(".section-group")).on(
      {
        mouseover: event => {
          const code = this._codeForEmojiButton($(event.currentTarget));
          const html = `<img src="${emojiUrlFor(
            code
          )}" class="emoji"> <span>:${code}:<span>`;
          replaceInfoContent(html);
        },
        mouseleave: () => replaceInfoContent()
      },
      "button.emoji"
    );
  },

  _bindResizing() {
    $(window).on("resize", () => {
      run.throttle(this, this._positionPicker, 16);
    });

    $("#reply-control").on("div-resizing", () => {
      run.throttle(this, this._positionPicker, 16);
    });
  },

  _bindClearRecentEmojisGroup() {
    const $recent = this.$picker.find(
      ".section[data-section='recent'] .clear-recent"
    );
    $recent.on("click", () => {
      this.emojiStore.favorites = [];
      this.set("recentEmojis", []);
      this._scrollTo(0);
      return false;
    });
  },

  _bindEmojiClick($emojisContainer) {
    const handler = event => {
      const code = this._codeForEmojiButton($(event.currentTarget));

      if (
        $(event.currentTarget).parents(".section[data-section='recent']")
          .length === 0
      ) {
        this._trackEmojiUsage(code);
      }

      this.emojiSelected(code);

      if (this.$modal.hasClass("fadeIn")) {
        this.set("active", false);
      }

      return false;
    };

    if (this.site.isMobileDevice) {
      const self = this;

      $emojisContainer
        .off("touchstart")
        .on("touchstart", "button.emoji", touchStartEvent => {
          const $this = $(touchStartEvent.currentTarget);

          $this.on("touchend", touchEndEvent => {
            touchEndEvent.preventDefault();
            touchEndEvent.stopPropagation();

            handler.bind(self)(touchEndEvent);
            $this.off("touchend");
          });

          $this.on("touchmove", () => $this.off("touchend"));
        });
    } else {
      $emojisContainer
        .off("click")
        .on("click", "button.emoji", e => handler.bind(this)(e));
    }
  },

  _bindSectionsScroll() {
    let onScroll = () => {
      run.debounce(this, this._checkVisibleSection, 50);
    };

    this.$list.on("scroll", onScroll);
    this._refreshInterval = setInterval(onScroll, 100);
  },

  _checkVisibleSection(force) {
    // make sure we stop loading if picker has been removed
    if (!this.$picker) {
      return;
    }

    const newPosition = this.$list.scrollTop();
    if (newPosition === this.scrollPosition && !force) {
      return;
    }

    this.scrollPosition = newPosition;

    const $sections = this.$list.find(".section");
    const listHeight = this.$list.innerHeight();
    let $selectedSection;

    this.$visibleSections = _.filter($sections, section => {
      const $section = $(section);
      const sectionTop = $section.position().top;
      return sectionTop + $section.height() > 0 && sectionTop < listHeight;
    });

    if (!_.isEmpty(this.recentEmojis) && this.scrollPosition === 0) {
      $selectedSection = $(_.first(this.$visibleSections));
    } else {
      $selectedSection = $(_.last(this.$visibleSections));
    }

    if ($selectedSection) {
      this.$picker.find(".category-icon").removeClass("current");
      this.$picker
        .find(
          `.category-icon button[data-section='${$selectedSection.data(
            "section"
          )}']`
        )
        .parent()
        .addClass("current");

      this._loadVisibleSections();
    }
  },

  _loadVisibleSections() {
    if (!this.$visibleSections) {
      return;
    }

    const listHeight = this.$list.innerHeight();

    this.$visibleSections.forEach(visibleSection => {
      const $unloadedEmojis = $(visibleSection).find(
        "button.emoji[data-loaded!='1']"
      );
      $.each($unloadedEmojis, (_, button) => {
        let offsetTop = button.offsetTop;

        if (offsetTop < this.scrollPosition + listHeight + 200) {
          if (offsetTop + 200 > this.scrollPosition) {
            const $button = $(button);
            this._setButtonBackground($button);
          }
        }
      });
    });
  },

  _bindDiversityClick() {
    const $diversityScales = this.$picker.find(
      ".diversity-picker .diversity-scale"
    );
    $diversityScales.on("click", event => {
      const $selectedDiversity = $(event.currentTarget);
      this.set("selectedDiversity", parseInt($selectedDiversity.data("level")));
      return false;
    });
  },

  _isReplyControlExpanded() {
    const verticalSpace =
      $(window).height() -
      $(".d-header").height() -
      $("#reply-control").height();

    return verticalSpace < this.$picker.height() - 48;
  },

  _positionPicker() {
    if (!this.active) {
      return;
    }

    let windowWidth = $(window).width();

    const desktopModalePositioning = options => {
      let attributes = {
        width: Math.min(windowWidth, 400) - 12,
        marginLeft: -(Math.min(windowWidth, 400) / 2) + 6,
        marginTop: -130,
        left: "50%",
        bottom: "",
        top: "50%",
        display: "flex"
      };

      this.$modal.addClass("fadeIn");
      this.$picker.css(_.merge(attributes, options));
    };

    const mobilePositioning = options => {
      let attributes = {
        width: windowWidth,
        marginLeft: 0,
        marginTop: "auto",
        left: 0,
        bottom: "",
        top: 0,
        display: "flex"
      };

      this.$modal.addClass("fadeIn");
      this.$picker.css(_.merge(attributes, options));
    };

    const desktopPositioning = options => {
      let attributes = {
        position: "fixed",
        width: windowWidth < 485 ? windowWidth - 12 : 400,
        marginLeft: "",
        marginTop: "",
        right: "",
        left: "",
        bottom: 32,
        top: "",
        display: "flex"
      };

      this.$modal.removeClass("fadeIn");
      this.$picker.css(_.merge(attributes, options));
    };

    if (Ember.testing || !this.automaticPositioning) {
      desktopPositioning();
      return;
    }

    if (this.site.isMobileDevice) {
      mobilePositioning();
    } else {
      if (this._isReplyControlExpanded()) {
        let $editorWrapper = $(".d-editor-preview-wrapper");
        if (
          ($editorWrapper.is(":visible") && $editorWrapper.width() < 400) ||
          windowWidth < 485
        ) {
          desktopModalePositioning();
        } else {
          if ($editorWrapper.is(":visible")) {
            let previewOffset = $(".d-editor-preview-wrapper").offset();
            let replyControlOffset = $("#reply-control").offset();
            let left = previewOffset.left - replyControlOffset.left;
            desktopPositioning({ left });
          } else {
            desktopPositioning({
              right:
                ($("#reply-control").width() -
                  $(".d-editor-container").width()) /
                2
            });
          }
        }
      } else {
        if (windowWidth < 485) {
          desktopModalePositioning();
        } else {
          const previewInputOffset = $(".d-editor-input").offset();

          const pickerHeight = $(".d-editor .emoji-picker").height();
          const editorHeight = $(".d-editor-input").height();
          const windowBottom = $(window).scrollTop() + $(window).height();

          if (
            previewInputOffset.top + editorHeight + pickerHeight <
            windowBottom
          ) {
            // position it below editor if there is enough space
            desktopPositioning({
              position: "absolute",
              top: previewInputOffset.top + editorHeight,
              left: previewInputOffset.left
            });
          } else {
            // try positioning it above
            desktopPositioning({
              position: "absolute",
              top: -pickerHeight,
              left: previewInputOffset.left
            });
          }
        }
      }
    }

    const infoMaxWidth =
      this.$picker.width() -
      this.$picker.find(".categories-column").width() -
      this.$picker.find(".diversity-picker").width() -
      32;
    this.$picker.find(".info").css("max-width", infoMaxWidth);
  },

  _codeWithDiversity(code, diversity) {
    if (diversity && this.selectedDiversity !== 1) {
      return `${code}:t${this.selectedDiversity}`;
    } else {
      return code;
    }
  },

  _trackEmojiUsage(code) {
    this.emojiStore.track(code);
    this.set("recentEmojis", this.emojiStore.favorites.slice(0, PER_ROW));
  },

  _scrollTo(y) {
    const yPosition = typeof y === "undefined" ? this.scrollPosition : y;

    this.$list.scrollTop(yPosition);

    // if we don’t actually scroll we need to force it
    if (yPosition === 0) {
      this.$list.scroll();
    }
  },

  _codeForEmojiButton($button) {
    const title = $button.attr("title");
    return this._codeWithDiversity(title, $button.hasClass("diversity"));
  },

  _setButtonBackground(button, diversity) {
    if (!button) {
      return;
    }

    const $button = $(button);
    button = $button[0];

    // changing style can force layout events
    // this could slow down timers and lead to
    // chrome delaying the request
    window.requestAnimationFrame(() => {
      const code = this._codeWithDiversity(
        $button.attr("title"),
        diversity || $button.hasClass("diversity")
      );

      // // force visual reloading if needed
      if (button.style.backgroundImage !== "none") {
        button.style.backgroundImage = "";
      }

      button.style.backgroundImage = `url("${emojiUrlFor(code)}")`;
      $button.attr("data-loaded", 1);
    });
  }
});
