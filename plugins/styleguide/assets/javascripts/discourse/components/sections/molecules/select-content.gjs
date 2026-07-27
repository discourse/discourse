import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import {
  delay,
  localTimeIn,
  makeFailingLoader,
  PEOPLE,
  TEAM_MEMBERS,
  teamLabels,
  TIMEZONES,
  topics,
} from "../../../lib/select-fixtures";
import StyleguideExample from "../../styleguide-example";

/** Enough rows to scroll without making the windowing the subject of the card. */
const GLYPH_TOPICS = topics().slice(0, 40);

/**
 * The same footer, rendered by three controls in different panel states.
 *
 * Its contents are gated on `loadedCount` rather than assuming rows exist, which is the whole
 * point of the card: this block renders over the empty and error states too.
 */
const FooterContents = <template>
  {{#if @state.loadedCount}}
    <span class="select-examples__footer-count">
      {{i18n
        "styleguide.sections.select.content.footer_count"
        count=@state.loadedCount
      }}
    </span>
  {{else}}
    <span class="select-examples__footer-count">
      {{i18n "styleguide.sections.select.content.footer_nothing"}}
    </span>
  {{/if}}
  <DButton
    class="btn-transparent"
    @action={{@state.close}}
    @icon="arrow-up-right-from-square"
    @label="styleguide.sections.select.content.footer_view_all"
  />
</template>;

/**
 * The `content` group: how a consumer controls what a row renders.
 *
 * Two halves. The first teaches one block at a time — what the component keeps versus what your
 * block replaces. The second teaches what changes when blocks co-occur, which is how they are
 * actually used and where the two real footguns live (a footer that outlives its list, and a
 * group header whose text is read after every option beneath it).
 *
 * The rule every card states: a block is justified only when the component's default cannot
 * express the content. Most rows on this page correctly have no block at all.
 */
export default class SelectContent extends Component {
  @tracked chipsValue = [101, 103];
  @tracked computedValue = "Europe/London";
  @tracked defaultsValue = 102;
  @tracked emptyValue = null;
  @tracked errorValue = null;
  @tracked footerEmptyValue = null;
  @tracked footerErrorValue = null;
  @tracked footerValue = null;
  @tracked glyphValue = null;
  @tracked groupedValue = null;
  @tracked pickerValue = [];
  @tracked selectionValue = 101;

  people = PEOPLE;
  teamMembers = TEAM_MEMBERS;
  timezones = TIMEZONES;
  glyphTopics = GLYPH_TOPICS;

  // `alternate` rather than `first`: an error you can only reach once per page load reads as a
  // broken example to anyone who opens it twice.
  failingLoader = makeFailingLoader({
    items: PEOPLE,
    failOn: "alternate",
    delayMs: 600,
  });

  defaultsCode = `{{! No blocks. @labelField and @selectedIcon already cover this row. }}
<DSelect
  @items={{this.people}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @labelField="name"
  @selectedIcon="check"
/>`;

  glyphCode = `<DSelect @items={{this.topics}} @value={{this.value}} @onChange={{this.onChange}}>
  {{! :item only. The trigger is one line, so it keeps the default label. }}
  <:item as |topic|>
    <span class="select-examples__row select-examples__row--glyph">
      <span class="select-examples__bullet" style={{topic.categoryColor}}></span>
      <span class="select-examples__primary">{{topic.name}}</span>
      <span class="select-examples__meta">{{topic.repliesLabel}}</span>
    </span>
  </:item>
</DSelect>`;

  computedCode = `{{! The block runs when the row renders, so it can derive rather than read. }}
<:item as |zone|>
  <span class="select-examples__row select-examples__row--glyph">
    {{dIcon "clock"}}
    <span class="select-examples__primary">{{zone.name}}</span>
    <span class="select-examples__meta">{{localTimeIn zone.id}}</span>
  </span>
</:item>`;

  emptyCode = `{{! The wrapper and its role="status" are kept for you; only the message is yours. }}
<DSelect @load={{this.load}} @value={{this.value}} @onChange={{this.onChange}}>
  <:empty>Nothing matches that yet. Try a shorter term.</:empty>
</DSelect>`;

  errorCode = `{{! Unlike every other block, :error replaces the WHOLE container — including its
  role="alert" and its retry button. Supply both or the state stops being
  announced and stops being recoverable. }}
<:error as |error retry|>
  <div class="select-examples__error" role="alert">
    <p>{{error.message}}</p>
    <DButton @action={{retry}} @label="..." />
  </div>
</:error>`;

  selectionCode = `{{! Two surfaces, deliberately different: a two-line row in the list, a
  one-line summary in the trigger, which is only one line tall. }}
<:item as |person|>
  <span class="select-examples__row select-examples__row--identity">
    <img class="select-examples__avatar" src={{person.avatar}} alt="" />
    <span class="select-examples__details">
      <span class="select-examples__primary">{{person.name}}</span>
      <span class="select-examples__secondary">@{{person.username}}</span>
    </span>
  </span>
</:item>
<:selection as |person|>
  <span class="select-examples__row select-examples__row--glyph">
    <img class="select-examples__avatar --small" src={{person.avatar}} alt="" />
    {{person.name}}
  </span>
</:selection>`;

  groupedCode = `<DSelect
  @items={{this.members}}
  @groupBy="team"
  @groupLabel={{this.teamLabel}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @labelField="name"
>
  {{! Keep it short: each option is aria-describedby its header, so whatever
  this renders is announced again after every row in the group. }}
  <:groupHeader as |group|>
    <span class="select-examples__group-header">
      {{dIcon "users"}}{{group.label}}
    </span>
  </:groupHeader>
  <:item as |person|>...</:item>
</DSelect>`;

  footerCode = `{{! The footer is a SIBLING of the async content, not inside it, so it renders in
  every panel state — loading, populated, empty and errored. Gate its contents
  on what it is yielded rather than assuming a populated list. }}
<:footer as |state|>
  {{#if state.loadedCount}}
    <span>{{state.loadedCount}} shown</span>
  {{else}}
    <span>Nothing to show</span>
  {{/if}}
  <DButton @action={{state.close}} @label="..." />
</:footer>

// Three controls rather than one with a toggle: a DSelect captures @load when its
// engine is built, so the source of a live control cannot be swapped underneath it.`;

  pickerCode = `<DSelect
  @items={{this.members}}
  @multiple={{true}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @groupBy="team"
  @groupLabel={{this.teamLabel}}
  @labelField="name"
>
  {{! Four blocks at once. Nothing new is needed to combine them — the rows, the
  header, the compact chip and the footer each keep the contract they had
  on their own. }}
  <:groupHeader as |group|>…</:groupHeader>
  <:item as |person|>…</:item>
  <:selection as |person|>…</:selection>
  <:footer as |state|>…</:footer>
</DSelect>`;

  get glyphItems() {
    return this.glyphTopics.map((topic) => ({
      ...topic,
      categoryColor: trustHTML(`--bullet-color: #${topic.category.color}`),
      repliesLabel: i18n("styleguide.sections.select.content.glyph_replies", {
        count: topic.replies,
      }),
    }));
  }

  @action
  teamLabel(key) {
    return teamLabels()[key] ?? key;
  }

  @action
  async loadPeople(filter, { signal }) {
    await delay(signal, 400);
    return this.people.filter((person) =>
      person.name.toLowerCase().includes(filter.toLowerCase())
    );
  }

  @action
  async loadEmpty(_filter, { signal }) {
    await delay(signal, 400);
    return [];
  }

  @action
  async loadBroken(_filter, { signal }) {
    await delay(signal, 400);
    throw new Error("The source could not be reached.");
  }

  @action
  updateFooterEmpty(value) {
    this.footerEmptyValue = value;
  }

  @action
  updateFooterError(value) {
    this.footerErrorValue = value;
  }

  @action
  updateChips(value) {
    this.chipsValue = value;
  }

  @action
  updateComputed(value) {
    this.computedValue = value;
  }

  @action
  updateDefaults(value) {
    this.defaultsValue = value;
  }

  @action
  updateEmpty(value) {
    this.emptyValue = value;
  }

  @action
  updateError(value) {
    this.errorValue = value;
  }

  @action
  updateFooter(value) {
    this.footerValue = value;
  }

  @action
  updateGlyph(value) {
    this.glyphValue = value;
  }

  @action
  updateGrouped(value) {
    this.groupedValue = value;
  }

  @action
  updatePicker(value) {
    this.pickerValue = value;
  }

  @action
  updateSelection(value) {
    this.selectionValue = value;
  }

  <template>
    <p class="styleguide-group__intro">
      {{i18n "styleguide.sections.select.content.intro"}}
    </p>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.content.defaults_example"}}
      @description={{i18n
        "styleguide.sections.select.content.defaults_description"
      }}
      @tryThis={{i18n "styleguide.sections.select.content.defaults_try_this"}}
      @code={{this.defaultsCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @identifier="sg-content-defaults"
          @items={{this.people}}
          @value={{this.defaultsValue}}
          @onChange={{this.updateDefaults}}
          @labelField="name"
          @selectedIcon="check"
        />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.content.glyph_example"}}
      @description={{i18n
        "styleguide.sections.select.content.glyph_description"
      }}
      @tryThis={{i18n "styleguide.sections.select.content.glyph_try_this"}}
      @code={{this.glyphCode}}
    >
      <div class="select-examples__control select-examples__control--wide">
        <DSelect
          @identifier="sg-content-glyph"
          @items={{this.glyphItems}}
          @value={{this.glyphValue}}
          @onChange={{this.updateGlyph}}
          @placeholder={{i18n
            "styleguide.sections.select.content.glyph_placeholder"
          }}
        >
          <:item as |topic|>
            <span class="select-examples__row select-examples__row--glyph">
              {{! Decorative: the category name is not repeated in the row, and a bullet with no
              text would only add noise to the announced option. }}
              <span
                class="select-examples__bullet"
                style={{topic.categoryColor}}
                aria-hidden="true"
              ></span>
              <span class="select-examples__primary">{{topic.name}}</span>
              <span class="select-examples__meta">{{topic.repliesLabel}}</span>
            </span>
          </:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.content.computed_example"}}
      @description={{i18n
        "styleguide.sections.select.content.computed_description"
      }}
      @tryThis={{i18n "styleguide.sections.select.content.computed_try_this"}}
      @code={{this.computedCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @identifier="sg-content-computed"
          @items={{this.timezones}}
          @value={{this.computedValue}}
          @onChange={{this.updateComputed}}
          @placeholder={{i18n
            "styleguide.sections.select.content.computed_placeholder"
          }}
        >
          <:item as |zone|>
            <span class="select-examples__row select-examples__row--glyph">
              {{dIcon "clock"}}
              <span class="select-examples__primary">{{zone.name}}</span>
              <span class="select-examples__meta">{{localTimeIn zone.id}}</span>
            </span>
          </:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.content.empty_example"}}
      @description={{i18n
        "styleguide.sections.select.content.empty_description"
      }}
      @tryThis={{i18n "styleguide.sections.select.content.empty_try_this"}}
      @code={{this.emptyCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @identifier="sg-custom-empty"
          @load={{this.loadEmpty}}
          @value={{this.emptyValue}}
          @onChange={{this.updateEmpty}}
          @variant="button"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          {{! The wrapper and its status role are the component's; only the message is ours. }}
          <:empty>
            {{i18n "styleguide.sections.select.content.empty_body"}}
          </:empty>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.content.error_example"}}
      @description={{i18n
        "styleguide.sections.select.content.error_description"
      }}
      @tryThis={{i18n "styleguide.sections.select.content.error_try_this"}}
      @code={{this.errorCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @identifier="sg-content-error"
          @load={{this.failingLoader}}
          @value={{this.errorValue}}
          @onChange={{this.updateError}}
          @variant="button"
          @labelField="name"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          {{! This block replaces the entire error container, so the alert role and the retry
          control have to be supplied here or they are simply gone. }}
          <:error as |error retry|>
            <div class="select-examples__error" role="alert">
              <span class="select-examples__error-message">
                {{dIcon "triangle-exclamation"}}
                {{error.message}}
              </span>
              <DButton
                class="btn-flat"
                @action={{retry}}
                @label="styleguide.sections.select.content.error_retry"
              />
            </div>
          </:error>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.content.selection_example"}}
      @description={{i18n
        "styleguide.sections.select.content.selection_description"
      }}
      @tryThis={{i18n "styleguide.sections.select.content.selection_try_this"}}
      @code={{this.selectionCode}}
    >
      <div class="select-examples__pair">
        <div class="select-examples__pair-item">
          <p class="select-examples__pair-label">
            {{i18n "styleguide.sections.select.content.selection_single_label"}}
          </p>
          <div class="select-examples__control select-examples__selection">
            <DSelect
              @identifier="sg-selection"
              @items={{this.people}}
              @value={{this.selectionValue}}
              @onChange={{this.updateSelection}}
              @labelField="name"
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            >
              <:item as |person|>
                <span
                  class="select-examples__row select-examples__row--identity"
                >
                  <img
                    class="select-examples__avatar"
                    src={{person.avatar}}
                    alt=""
                  />
                  <span class="select-examples__details">
                    <span
                      class="select-examples__primary"
                    >{{person.name}}</span>
                    <span class="select-examples__secondary">
                      {{if
                        person.title
                        person.title
                        (concat "@" person.username)
                      }}
                    </span>
                  </span>
                </span>
              </:item>
              <:selection as |person|>
                <span class="select-examples__row select-examples__row--glyph">
                  <img
                    class="select-examples__avatar --small"
                    src={{person.avatar}}
                    alt=""
                  />
                  {{person.name}}
                </span>
              </:selection>
            </DSelect>
          </div>
        </div>
        <div class="select-examples__pair-item">
          <p class="select-examples__pair-label">
            {{i18n "styleguide.sections.select.content.selection_multi_label"}}
          </p>
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-content-chips"
              @items={{this.people}}
              @multiple={{true}}
              @value={{this.chipsValue}}
              @onChange={{this.updateChips}}
              @labelField="name"
              @placeholder={{i18n
                "styleguide.sections.select.multi_placeholder"
              }}
            >
              <:item as |person|>
                <span
                  class="select-examples__row select-examples__row--identity"
                >
                  <img
                    class="select-examples__avatar"
                    src={{person.avatar}}
                    alt=""
                  />
                  <span class="select-examples__details">
                    <span
                      class="select-examples__primary"
                    >{{person.name}}</span>
                    <span class="select-examples__secondary">
                      {{if
                        person.title
                        person.title
                        (concat "@" person.username)
                      }}
                    </span>
                  </span>
                </span>
              </:item>
              {{! The chip's accessible name is built from whatever this renders, so it has to
              carry text. An avatar-only chip would be announced as a bare remove button. }}
              <:selection as |person|>
                <span class="select-examples__row select-examples__row--glyph">
                  <img
                    class="select-examples__avatar --small"
                    src={{person.avatar}}
                    alt=""
                  />
                  {{person.name}}
                </span>
              </:selection>
            </DSelect>
          </div>
        </div>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.content.grouped_example"}}
      @description={{i18n
        "styleguide.sections.select.content.grouped_description"
      }}
      @tryThis={{i18n "styleguide.sections.select.content.grouped_try_this"}}
      @code={{this.groupedCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @identifier="sg-grouped"
          @items={{this.teamMembers}}
          @value={{this.groupedValue}}
          @onChange={{this.updateGrouped}}
          @groupBy="team"
          @groupLabel={{this.teamLabel}}
          @labelField="name"
          @placeholder={{i18n
            "styleguide.sections.select.content.grouped_placeholder"
          }}
        >
          {{! Kept to an icon and the team name. Every option under this header is
          aria-describedby it, so anything extra here is read again on every row. }}
          <:groupHeader as |group|>
            <span class="select-examples__group-header">
              {{dIcon "users"}}
              {{group.label}}
            </span>
          </:groupHeader>
          <:item as |person|>
            <span class="select-examples__row select-examples__row--identity">
              <img
                class="select-examples__avatar"
                src={{person.avatar}}
                alt=""
              />
              <span class="select-examples__details">
                <span class="select-examples__primary">{{person.name}}</span>
                <span class="select-examples__secondary">
                  @{{person.username}}
                </span>
              </span>
            </span>
          </:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.content.footer_example"}}
      @description={{i18n
        "styleguide.sections.select.content.footer_description"
      }}
      @tryThis={{i18n "styleguide.sections.select.content.footer_try_this"}}
      @code={{this.footerCode}}
    >
      {{! Three controls rather than one with a state toggle. A DSelect captures its source when
      its engine is built, so a source cannot be swapped underneath a live control — and showing
      the three states at once is a better demonstration anyway: the footer's persistence is
      visible in a glance instead of requiring the reader to operate a switch. }}
      <div class="select-examples__triple">
        <div class="select-examples__pair-item">
          <p class="select-examples__pair-label">
            {{i18n "styleguide.sections.select.content.footer_state_items"}}
          </p>
          <DSelect
            @identifier="sg-footer"
            @load={{this.loadPeople}}
            @value={{this.footerValue}}
            @onChange={{this.updateFooter}}
            @labelField="name"
            @placeholder={{i18n "styleguide.sections.select.placeholder"}}
          >
            <:footer as |state|><FooterContents @state={{state}} /></:footer>
          </DSelect>
        </div>
        <div class="select-examples__pair-item">
          <p class="select-examples__pair-label">
            {{i18n "styleguide.sections.select.content.footer_state_empty"}}
          </p>
          <DSelect
            @identifier="sg-footer-empty"
            @load={{this.loadEmpty}}
            @value={{this.footerEmptyValue}}
            @onChange={{this.updateFooterEmpty}}
            @labelField="name"
            @placeholder={{i18n "styleguide.sections.select.placeholder"}}
          >
            <:footer as |state|><FooterContents @state={{state}} /></:footer>
          </DSelect>
        </div>
        <div class="select-examples__pair-item">
          <p class="select-examples__pair-label">
            {{i18n "styleguide.sections.select.content.footer_state_error"}}
          </p>
          <DSelect
            @identifier="sg-footer-error"
            @load={{this.loadBroken}}
            @value={{this.footerErrorValue}}
            @onChange={{this.updateFooterError}}
            @labelField="name"
            @placeholder={{i18n "styleguide.sections.select.placeholder"}}
          >
            <:footer as |state|><FooterContents @state={{state}} /></:footer>
          </DSelect>
        </div>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.content.picker_example"}}
      @description={{i18n
        "styleguide.sections.select.content.picker_description"
      }}
      @tryThis={{i18n "styleguide.sections.select.content.picker_try_this"}}
      @code={{this.pickerCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @identifier="sg-content-picker"
          @items={{this.teamMembers}}
          @multiple={{true}}
          @value={{this.pickerValue}}
          @onChange={{this.updatePicker}}
          @groupBy="team"
          @groupLabel={{this.teamLabel}}
          @labelField="name"
          @placeholder={{i18n
            "styleguide.sections.select.content.picker_placeholder"
          }}
        >
          <:groupHeader as |group|>
            <span class="select-examples__group-header">
              {{dIcon "users"}}
              {{group.label}}
            </span>
          </:groupHeader>
          <:item as |person|>
            <span class="select-examples__row select-examples__row--identity">
              <img
                class="select-examples__avatar"
                src={{person.avatar}}
                alt=""
              />
              <span class="select-examples__details">
                <span class="select-examples__primary">{{person.name}}</span>
                <span class="select-examples__secondary">
                  {{if person.status person.status person.title}}
                </span>
              </span>
            </span>
          </:item>
          <:selection as |person|>
            <span class="select-examples__row select-examples__row--glyph">
              <img
                class="select-examples__avatar --small"
                src={{person.avatar}}
                alt=""
              />
              {{person.name}}
            </span>
          </:selection>
          <:footer as |state|>
            <span class="select-examples__footer-count">
              {{i18n
                "styleguide.sections.select.content.picker_selected"
                count=state.value.length
              }}
            </span>
          </:footer>
        </DSelect>
      </div>
    </StyleguideExample>
  </template>
}
