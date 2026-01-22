import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DSheet from "discourse/float-kit/components/d-sheet";

const DETENTS = ["66vh"];

class BottomSheetScrollArea extends Component {
  <template>
    <DSheet.Scroll.Root as |controller|>
      <DSheet.Scroll.View
        class="bottom-sheet__scroll-view"
        @scrollGesture={{if @reachedLastDetent "auto" false}}
        @scrollGestureTrap={{hash yEnd=true}}
        @safeArea="layout-viewport"
        @onScrollStart={{hash dismissKeyboard=true}}
        @controller={{controller}}
      >
        <DSheet.Scroll.Content
          class="bottom-sheet__scroll-content"
          @controller={{controller}}
        >
          {{yield}}
        </DSheet.Scroll.Content>
      </DSheet.Scroll.View>
    </DSheet.Scroll.Root>
  </template>
}

class ExpandableView extends Component {
  @action
  handleTravelStatusChange(status) {
    if (status === "idleOutside") {
      this.args.setReachedLastDetent(false);
    }
  }

  @action
  handleTravelRangeChange(range) {
    if (range.start === 2 && !this.args.reachedLastDetent) {
      this.args.setReachedLastDetent(true);
    }
  }

  @action
  handleTravel(event) {
    if (event.progress < 0.999 && this.view) {
      if (!this.view.contains(document.activeElement)) {
        this.view.focus();
      }
    }
  }

  @action
  registerView(element) {
    this.view = element;
  }

  <template>
    <DSheet.View
      class="bottom-sheet__view"
      @sheet={{@sheet}}
      @detents={{unless @reachedLastDetent DETENTS}}
      @swipeOvershoot={{false}}
      @onTravelStatusChange={{this.handleTravelStatusChange}}
      @onTravelRangeChange={{this.handleTravelRangeChange}}
      @onTravel={{this.handleTravel}}
      {{didInsert this.registerView}}
    >
      {{yield}}
    </DSheet.View>
  </template>
}

const BottomSheetContent = <template>
  <DSheet.Portal @sheet={{@sheet}}>
    {{#if @expandable}}
      <ExpandableView
        @sheet={{@sheet}}
        @reachedLastDetent={{@reachedLastDetent}}
        @setReachedLastDetent={{@setReachedLastDetent}}
      >
        <DSheet.Backdrop @sheet={{@sheet}} />
        <DSheet.Content
          class="bottom-sheet__content --expandable"
          @sheet={{@sheet}}
        >
          <DSheet.BleedingBackground
            @sheet={{@sheet}}
            class="bottom-sheet__bleeding-background"
          />
          <DSheet.Handle
            class="bottom-sheet__handle"
            @sheet={{@sheet}}
            @action={{if @reachedLastDetent "dismiss" "step"}}
          />
          {{yield
            (hash
              ScrollArea=(component
                BottomSheetScrollArea
                reachedLastDetent=@reachedLastDetent
              )
              Trigger=(component DSheet.Trigger sheet=@sheet)
              expand=(fn @sheet.stepToDetent 2)
              isExpanded=@reachedLastDetent
              dismiss=@sheet.close
            )
          }}
        </DSheet.Content>
      </ExpandableView>
    {{else}}
      <DSheet.View @sheet={{@sheet}}>
        <DSheet.Backdrop @sheet={{@sheet}} />
        <DSheet.Content class="bottom-sheet__content" @sheet={{@sheet}}>
          <DSheet.BleedingBackground
            @sheet={{@sheet}}
            class="bottom-sheet__bleeding-background"
          />
          <DSheet.Handle
            class="bottom-sheet__handle"
            @sheet={{@sheet}}
            @action="dismiss"
          />
          {{yield
            (hash
              ScrollArea=(component BottomSheetScrollArea reachedLastDetent=false)
              Trigger=(component DSheet.Trigger sheet=@sheet)
              dismiss=@sheet.close
            )
          }}
        </DSheet.Content>
      </DSheet.View>
    {{/if}}
  </DSheet.Portal>
</template>;

export default class DBottomSheet extends Component {
  @tracked reachedLastDetent = false;

  get componentId() {
    return this.args.componentId ?? guidFor(this);
  }

  @action
  setReachedLastDetent(value) {
    if (this.reachedLastDetent !== value) {
      this.reachedLastDetent = value;
    }
  }

  <template>
    <DSheet.Root
      class="bottom-sheet"
      @componentId={{this.componentId}}
      ...attributes
      as |sheet|
    >
      {{yield
        (hash
          Trigger=(component
            DSheet.Trigger
            forComponent=this.componentId
            sheet=sheet
          )
          Content=(component
            BottomSheetContent
            sheet=sheet
            expandable=@expandable
            reachedLastDetent=this.reachedLastDetent
            setReachedLastDetent=this.setReachedLastDetent
          )
          present=sheet.open
          dismiss=sheet.close
        )
      }}
    </DSheet.Root>
  </template>
}
