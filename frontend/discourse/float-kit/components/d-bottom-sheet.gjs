import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DSheet from "discourse/float-kit/components/d-sheet";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";

const DETENTS = ["66vh"];
const BottomSheetScrollArea = <template>
  <DSheet.Scroll.Root class="bottom-sheet__scroll-root" as |controller|>
    <DSheet.Scroll.View
      class="bottom-sheet__scroll-view"
      @scrollGesture={{if @reachedLastDetent "auto" false}}
      @scrollGestureTrap={{hash yEnd=true}}
      @safeArea="layout-viewport"
      @onScrollStart={{hash dismissKeyboard=true}}
      @controller={{controller}}
      @sheet={{@sheet}}
    >
      <DSheet.Scroll.Content
        class="bottom-sheet__scroll-content"
        @controller={{controller}}
      >
        {{yield}}
      </DSheet.Scroll.Content>
    </DSheet.Scroll.View>
  </DSheet.Scroll.Root>
</template>;
class ExpandableView extends Component {
  view;

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
const BottomSheetInnerContent = <template>
  <DSheet.Backdrop @sheet={{@sheet}} />
  <DSheet.Content @sheet={{@sheet}} as |ContentTag|>
    <ContentTag
      class={{concatClass
        "bottom-sheet__content"
        (if @expandable "--expandable")
      }}
    >
      <DSheet.BleedingBackground
        @sheet={{@sheet}}
        class="bottom-sheet__bleeding-background"
      />
      <DSheet.Handle
        class="bottom-sheet__handle"
        @sheet={{@sheet}}
        @action={{@handleAction}}
      />
      {{yield}}
    </ContentTag>
  </DSheet.Content>
</template>;
const BottomSheetContent = <template>
  <DSheet.Portal @sheet={{@sheet}}>
    {{#if @expandable}}
      <ExpandableView
        @sheet={{@sheet}}
        @reachedLastDetent={{@reachedLastDetent}}
        @setReachedLastDetent={{@setReachedLastDetent}}
      >
        <BottomSheetInnerContent
          @sheet={{@sheet}}
          @expandable={{true}}
          @handleAction={{if @reachedLastDetent "dismiss" "step"}}
        >
          {{yield
            (hash
              ScrollArea=(component
                BottomSheetScrollArea
                reachedLastDetent=@reachedLastDetent
                sheet=@sheet
              )
              Trigger=(component DSheet.Trigger sheet=@sheet)
              expand=(fn @sheet.stepToDetent 2)
              isExpanded=@reachedLastDetent
              dismiss=@sheet.requestDismiss
            )
          }}
        </BottomSheetInnerContent>
      </ExpandableView>
    {{else}}
      <DSheet.View class="bottom-sheet__view" @sheet={{@sheet}}>
        <BottomSheetInnerContent
          @sheet={{@sheet}}
          @expandable={{false}}
          @handleAction="dismiss"
        >
          {{yield
            (hash
              ScrollArea=(component
                BottomSheetScrollArea reachedLastDetent=false sheet=@sheet
              )
              Trigger=(component DSheet.Trigger sheet=@sheet)
              dismiss=@sheet.requestDismiss
            )
          }}
        </BottomSheetInnerContent>
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
    this.reachedLastDetent = value;
  }

  <template>
    <DSheet.Root
      class="bottom-sheet"
      @componentId={{this.componentId}}
      @sheetRole="dialog"
      @defaultPresented={{@defaultPresented}}
      @presented={{@presented}}
      @onPresentedChange={{@onPresentedChange}}
      @onClosed={{@onClosed}}
      ...attributes
      as |sheet|
    >
      {{yield
        (hash
          Trigger=(component
            DSheet.Trigger forComponent=this.componentId sheet=sheet
          )
          Content=(component
            BottomSheetContent
            sheet=sheet
            expandable=@expandable
            reachedLastDetent=this.reachedLastDetent
            setReachedLastDetent=this.setReachedLastDetent
          )
          present=sheet.requestPresent
          dismiss=sheet.requestDismiss
        )
      }}
    </DSheet.Root>
  </template>
}
