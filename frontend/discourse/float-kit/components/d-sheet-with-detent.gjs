import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DScrollRoot from "./d-scroll/root";
import DSheet from "./d-sheet";

class DSheetWithDetent extends Component {
  @tracked reachedLastDetent = false;

  get detents() {
    return this.args.detents ?? ["66vh"];
  }

  @action
  setReachedLastDetent(value) {
    this.reachedLastDetent = value;
  }

  <template>
    <DSheet.Root @defaultPresented={{true}} as |sheet|>
      <DSheet.Portal @sheet={{sheet}}>
        <View
          @sheet={{sheet}}
          @setReachedLastDetent={{this.setReachedLastDetent}}
          @reachedLastDetent={{this.reachedLastDetent}}
          @detents={{this.detents}}
        >
          <DSheet.Backdrop
            class="SheetWithDetent-backdrop"
            {{! TODO IMPLEMENT }}
            @themeColorDimming="auto"
            @sheet={{sheet}}
          />
          <DSheet.Content class="SheetWithDetent-content" @sheet={{sheet}}>
            <DSheet.Handle
              class="SheetWithDetent-handle"
              @sheet={{sheet}}
              @action={{if this.reachedLastDetent "dismiss" "step"}}
            />

            <DScrollRoot class="SheetWithDetent-scrollRoot" as |scroll|>
              <scroll.View
                class="SheetWithDetent-scrollView"
                @scrollGesture={{if this.reachedLastDetent "auto" false}}
                @scrollGestureTrap={{hash yEnd=true}}
                @safeArea="layout-viewport"
                @onScrollStart={{hash dismissKeyboard=true}}
              >
                <scroll.Content class="SheetWithDetent-scrollContent">
                  {{yield}}
                </scroll.Content>
              </scroll.View>
            </DScrollRoot>
          </DSheet.Content>
        </View>
      </DSheet.Portal>
    </DSheet.Root>
  </template>
}

class View extends Component {
  get detents() {
    return this.args.reachedLastDetent ? undefined : this.args.detents;
  }

  @action
  handleTravelStatusChange(status) {
    if (status === "idleOutside") {
      this.args.setReachedLastDetent(false);
    }
    this.args.onTravelStatusChange?.(status);
  }

  @action
  handleTravelRangeChange(range) {
    if (range.start === 2 && !this.args.reachedLastDetent) {
      this.args.setReachedLastDetent(true);
    }
    this.args.onTravelRangeChange?.(range);
  }

  @action
  handleTravel(event) {
    if (event.progress < 0.999 && this.view) {
      this.view.focus();
    }
    this.args.onTravel?.(event);
  }

  @action
  registerView(element) {
    this.view = element;
  }

  <template>
    <DSheet.View
      class="SheetWithDetent-view"
      @sheet={{@sheet}}
      @detents={{this.detents}}
      @swipeOvershoot={{false}}
      @onTravelStatusChange={{this.handleTravelStatusChange}}
      @onTravelRangeChange={{this.handleTravelRangeChange}}
      @onTravel={{this.handleTravel}}
      {{didInsert this.registerView}}
      ...attributes
    >
      {{yield}}
    </DSheet.View>
  </template>
}

export default DSheetWithDetent;
