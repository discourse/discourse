import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import { not } from "discourse/truth-helpers";
import DScrollRoot from "./d-scroll/root";
import DSheet from "./d-sheet";
import DSheetBackdrop from "./d-sheet/backdrop";
import DSheetContent from "./d-sheet/content";
import DSheetView from "./d-sheet/view";

class Root extends Component {
  @tracked _largeViewport = false;

  _mediaQuery = null;
  _mediaQueryHandler = null;

  constructor(owner, args) {
    super(owner, args);
    this._setupMediaQuery();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this._cleanupMediaQuery();
  }

  _setupMediaQuery() {
    if (typeof window === "undefined") {
      return;
    }

    this._mediaQuery = window.matchMedia("(min-width: 800px)");
    this._largeViewport = this._mediaQuery.matches;

    this._mediaQueryHandler = (event) => {
      this._largeViewport = event.matches;
    };

    this._mediaQuery.addEventListener("change", this._mediaQueryHandler);
  }

  _cleanupMediaQuery() {
    if (this._mediaQuery && this._mediaQueryHandler) {
      this._mediaQuery.removeEventListener("change", this._mediaQueryHandler);
      this._mediaQuery = null;
      this._mediaQueryHandler = null;
    }
  }

  get contentPlacement() {
    return "bottom";
  }

  get tracks() {
    return "bottom";
  }

  <template>
    <DSheet.Root as |root|>
      {{yield
        (hash
          sheet=root.sheet
          largeViewport=this._largeViewport
          contentPlacement=this.contentPlacement
          openSheet=root.openSheet
          Trigger=root.Trigger
          Portal=root.Portal
          View=(component
            View
            sheet=root.sheet
            largeViewport=this._largeViewport
            detents=@detents
            contentPlacement=this.contentPlacement
            tracks=this.tracks
            onTravelStatusChange=@onTravelStatusChange
            onTravelRangeChange=@onTravelRangeChange
            onTravel=@onTravel
            onClickOutside=@onClickOutside
          )
          Backdrop=(component Backdrop sheet=root.sheet)
          Content=(component
            Content sheet=root.sheet contentPlacement=this.contentPlacement
          )
          ScrollView=(component
            ScrollView largeViewport=this._largeViewport sheet=root.sheet
          )
        )
      }}
    </DSheet.Root>
  </template>
}

class View extends Component {
  @action
  handleTravel(event) {
    if (event.progress < 0.999 && this.args.sheet) {
      this.args.sheet.focusView();
    }
    this.args.onTravel?.(event);
  }

  <template>
    <DSheetView
      class={{concatClass
        "SheetWithKeyboard-view"
        (concat "contentPlacement-" @contentPlacement)
        @class
      }}
      @sheet={{@sheet}}
      @detents={{@detents}}
      @contentPlacement={{@contentPlacement}}
      @tracks={{@tracks}}
      @swipeOvershoot={{false}}
      @nativeEdgeSwipePrevention={{true}}
      @onTravelStatusChange={{@onTravelStatusChange}}
      @onTravelRangeChange={{@onTravelRangeChange}}
      @onTravel={{this.handleTravel}}
      @onClickOutside={{@onClickOutside}}
      ...attributes
    >
      {{yield
        (hash
          Backdrop=(component Backdrop sheet=@sheet)
          Content=(component
            Content sheet=@sheet contentPlacement=@contentPlacement
          )
        )
      }}
    </DSheetView>
  </template>
}

const Backdrop = <template>
  <DSheetBackdrop
    class={{concatClass "SheetWithKeyboard-backdrop" @class}}
    @sheet={{@sheet}}
    ...attributes
  />
</template>;

const Content = <template>
  <DSheetContent
    class={{concatClass
      "SheetWithKeyboard-content"
      (concat "contentPlacement-" @contentPlacement)
      @class
    }}
    @sheet={{@sheet}}
    ...attributes
  >
    {{yield}}
  </DSheetContent>
</template>;

const ScrollView = <template>
  <DScrollRoot as |scroll|>
    <scroll.View
      class="SheetWithKeyboard-scrollView"
      @scrollGestureTrap={{hash yEnd=(not @largeViewport)}}
      @safeArea="visual-viewport"
      @onScrollStart={{hash dismissKeyboard=true}}
      @boundingContainer={{@sheet.content}}
      ...attributes
    >
      <scroll.Content class="SheetWithKeyboard-scrollContent">
        {{yield}}
      </scroll.Content>
    </scroll.View>
  </DScrollRoot>
</template>;

const DSheetWithKeyboard = {
  Root,
};

export default DSheetWithKeyboard;
