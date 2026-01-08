import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DSheet from "./d-sheet";

const DEFAULT_DETENTS = ["66vh"];

class DSheetWithDetent extends Component {
  @tracked reachedLastDetent = false;

  get detents() {
    return this.args.detents ?? DEFAULT_DETENTS;
  }

  @action
  setReachedLastDetent(value) {
    if (this.reachedLastDetent !== value) {
      this.reachedLastDetent = value;
    }
  }

  get componentId() {
    return this.args.componentId ?? guidFor(this);
  }

  <template>
    <DSheet.Root @componentId={{this.componentId}} as |sheet|>
      {{yield
        (hash
          Trigger=(component
            DSheet.Trigger forComponent=this.componentId sheet=sheet
          )
        )
        to="root"
      }}

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

            {{#if (has-block "content")}}
              {{yield
                (hash
                  Trigger=(component DSheet.Trigger sheet=sheet)
                  reachedLastDetent=this.reachedLastDetent
                )
                to="content"
              }}
            {{else}}
              {{yield
                (hash
                  Trigger=(component DSheet.Trigger sheet=sheet)
                  reachedLastDetent=this.reachedLastDetent
                )
              }}
            {{/if}}
          </DSheet.Content>
        </View>
      </DSheet.Portal>
    </DSheet.Root>
  </template>
}

class View extends Component {
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
      @detents={{unless @reachedLastDetent @detents}}
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
