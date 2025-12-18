import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
// import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import AsyncContent from "discourse/components/async-content";
import DButton from "discourse/components/d-button";
import FilterInput from "discourse/components/filter-input";
import TextArea from "discourse/components/textarea";
import DSheet from "discourse/float-kit/components/d-sheet";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import formatUsername from "discourse/helpers/format-username";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";
import userSearch, {
  eagerCompleteSearch,
  skipSearch,
} from "discourse/lib/user-search";
import { and } from "discourse/truth-helpers";

export default class AssignTopicSheet extends Component {
  @service taskActions;

  @tracked filter;
  @tracked sheetPresented = false;
  @tracked nestedSheetPresented = false;
  @tracked note = "";
  @tracked selectedAssignee = null;

  largeViewport = new TrackedMediaQuery("(min-width: 700px)");

  componentId = "test"; //guidFor(this);

  willDestroy() {
    super.willDestroy(...arguments);
    this.largeViewport.teardown();
  }

  get tracks() {
    return this.largeViewport.matches ? "right" : "bottom";
  }

  @action
  handleTravel(event) {
    if (event.progress < 0.999 && this.view) {
      this.view.focus();
    }
    this.args.onTravel?.(event);
  }

  @action
  setFilter(event) {
    this.filter = event.target.value;
  }

  @action
  async loadAssignees() {
    return userSearch({
      term: this.filter,
      includeGroups: true,
      customSearchOptions: {
        assignableGroups: true,
        defaultSearchResults: this.taskActions.suggestions,
      },
    }).then((result) => {
      if (typeof result === "string") {
        // do nothing promise probably got cancelled
      } else {
        return result;
      }
    });
  }

  @action
  registerView(element) {
    this.view = element;
  }

  @action
  assign(assignee) {
    // eslint-disable-next-line no-console
    console.log("assigning", assignee);
  }

  get stackingAnimation() {
    return this.tracks === "right"
      ? {
          translateX: ({ progress }) =>
            progress <= 1
              ? progress * -10 + "px"
              : `calc(-12.5px + 2.5px * ${progress})`,
          scale: [1, 0.933],
          transformOrigin: "0 50%",
        }
      : {
          translateY: ({ progress }) =>
            progress <= 1
              ? progress * -10 + "px"
              : `calc(-12.5px + 2.5px * ${progress})`,
          scale: [1, 0.933],
          transformOrigin: "50% 0",
        };
  }

  @action
  onSelectAssignee(assignee) {
    this.selectedAssignee = assignee;
    this.note = "";
    this.nestedSheetPresented = true;
  }

  get selectedAssigneeName() {
    if (!this.selectedAssignee) {
      return "";
    }
    return this.selectedAssignee.isUser
      ? this.selectedAssignee.username
      : this.selectedAssignee.name;
  }

  <template>
    <DSheet.Stack.Root as |stack|>
      <DSheet.Root
        @presented={{this.sheetPresented}}
        @onPresentedChange={{fn (mut this.sheetPresented)}}
        @componentId={{this.componentId}}
        @forComponent={{stack.stackId}}
        as |sheet|
      >
        <DButton
          class="btn-default"
          @action={{fn (mut this.sheetPresented) true}}
          @icon="user-plus"
        >
          Assign
        </DButton>

        <DSheet.Portal @sheet={{sheet}}>
          <DSheet.View
            class="assign-sheet__view"
            @swipeOvershoot={{false}}
            @onTravelStatusChange={{this.handleTravelStatusChange}}
            @onTravelRangeChange={{this.handleTravelRangeChange}}
            @onTravel={{this.handleTravel}}
            {{didInsert this.registerView}}
            @sheet={{sheet}}
            @tracks={{this.tracks}}
            ...attributes
          >
            <DSheet.Backdrop
              class="assign-sheet__backdrop"
              @themeColorDimming="auto"
              @sheet={{sheet}}
            />
            <DSheet.Content
              @stackingAnimation={{this.stackingAnimation}}
              class="assign-sheet__content"
              @sheet={{sheet}}
            >
              <div class="assign-sheet__inner-content">
                <div class="assign-sheet__wrapper">
                  <FilterInput
                    @filterAction={{this.setFilter}}
                    @icons={{hash left="magnifying-glass"}}
                  />
                </div>

                <AsyncContent @asyncData={{this.loadAssignees}}>
                  <:content as |asignees|>

                    <DSheet.Scroll.Root as |controller|>
                      <DSheet.Scroll.View
                        @scrollGestureTrap={{hash yEnd=true}}
                        @safeArea="layout-viewport"
                        @onScrollStart={{hash dismissKeyboard=true}}
                        @controller={{controller}}
                      >
                        <DSheet.Scroll.Content
                          class="SheetWithDetent-scrollContent"
                          @controller={{controller}}
                        >
                          {{#each asignees as |assignee|}}
                            <button
                              type="button"
                              class="assign-sheet__assignee"
                              {{on "click" (fn this.onSelectAssignee assignee)}}
                            >
                              <span class="assign-sheet__assignee-avatar">
                                {{#if assignee.isUser}}
                                  {{avatar assignee imageSize="medium"}}
                                {{else}}
                                  {{icon "users"}}
                                {{/if}}
                              </span>
                              <span class="assign-sheet__assignee-details">
                                <span class="assign-sheet__assignee-name">
                                  {{#if assignee.isUser}}
                                    {{formatUsername assignee.username}}
                                  {{else}}
                                    {{assignee.name}}
                                  {{/if}}
                                </span>
                                {{#if (and assignee.isUser assignee.name)}}
                                  <span
                                    class="assign-sheet__assignee-full-name"
                                  >
                                    {{assignee.name}}
                                  </span>
                                {{/if}}
                              </span>
                            </button>
                          {{/each}}
                        </DSheet.Scroll.Content>
                      </DSheet.Scroll.View>
                    </DSheet.Scroll.Root>
                  </:content>
                </AsyncContent>
                <DSheet.Root
                  @presented={{this.nestedSheetPresented}}
                  @onPresentedChange={{fn (mut this.nestedSheetPresented)}}
                  @forComponent={{stack.stackId}}
                  as |nestedSheet|
                >
                  <DSheet.Portal @sheet={{nestedSheet}}>
                    <DSheet.View
                      class="assign-sheet__view"
                      @sheet={{nestedSheet}}
                      @tracks={{this.tracks}}
                    >
                      <DSheet.Backdrop
                        class="assign-sheet__backdrop"
                        @sheet={{nestedSheet}}
                        ...attributes
                      />
                      <DSheet.Content
                        @sheet={{nestedSheet}}
                        @stackingAnimation={{this.stackingAnimation}}
                        class="assign-sheet__content"
                      >
                        <div
                          class="assign-sheet__inner-content assign-sheet__inner-content--nested"
                        >
                          <div class="assign-sheet__nested-form">
                            <TextArea
                              @value={{this.note}}
                              placeholder="Optional note"
                              class="assign-sheet__note-textarea"
                            />

                            <DButton
                              class="btn-primary assign-sheet__full-width-btn"
                              @action={{fn this.assign this.selectedAssignee}}
                              @translatedLabel={{concat
                                "Assign "
                                this.selectedAssigneeName
                              }}
                            />

                            <DButton
                              class="btn-default assign-sheet__full-width-btn"
                              @action={{fn
                                (mut this.nestedSheetPresented)
                                false
                              }}
                              @translatedLabel="Cancel"
                            />
                          </div>
                        </div>
                      </DSheet.Content>
                    </DSheet.View>
                  </DSheet.Portal>
                </DSheet.Root>
              </div>
            </DSheet.Content>
          </DSheet.View>
        </DSheet.Portal>
      </DSheet.Root>
    </DSheet.Stack.Root>
  </template>
}
