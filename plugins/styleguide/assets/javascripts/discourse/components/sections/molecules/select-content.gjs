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
  notificationLevels,
  PEOPLE,
  TEAM_MEMBERS,
  teamLabels,
  TIMEZONES,
  topics,
  USER_GROUPS,
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
  @tracked chipIconsValue = [1, 3];
  @tracked glyphValue = null;
  @tracked rowIconValue = "tracking";
  @tracked statusValue = null;
  @tracked groupedValue = null;
  @tracked pickerValue = [];
  @tracked selectionValue = 101;

  people = PEOPLE;
  userGroups = USER_GROUPS;
  teamMembers = TEAM_MEMBERS;
  timezones = TIMEZONES;
  glyphTopics = GLYPH_TOPICS;

  // `first` paired with a reset on close, rather than `alternate`. Alternating made the failure
  // reachable twice but tied it to the parity of a request counter, so an open that happened to
  // issue two requests landed on success and the card looked broken. Resetting makes every open
  // start from the failure, which is the loop the card's instruction describes.
  failingLoader = makeFailingLoader({
    items: PEOPLE,
    failOn: "first",
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

  computedCode = `{{! The block runs when the row renders, so it can derive rather than read.
  Nothing on the item carries the local time; it is computed per row. }}
<DSelect
  @items={{this.timezones}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @valueField="id"
  @labelField="name"
>
  <:item as |zone|>
    <span class="my-row">
      {{icon "clock"}}
      <span class="my-primary">{{zone.name}}</span>
      <span class="my-meta">{{localTimeIn zone.id}}</span>
    </span>
  </:item>
</DSelect>`;

  emptyCode = `{{! The wrapper and its role="status" are kept for you; only the message is yours. }}
<DSelect @load={{this.load}} @value={{this.value}} @onChange={{this.onChange}}>
  <:empty>Nothing matches that yet. Try a shorter term.</:empty>
</DSelect>`;

  errorCode = `{{! Like every other block, :error supplies contents, not structure: the container
  and its role="alert" are kept for you, so the failure stays announced whatever
  you render. Retry is yielded for a block that wants its own control. }}
<DSelect
  @load={{this.load}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @retryable={{true}}
>
  <:error as |error retry|>
    <span class="my-error-message">{{error.message}}</span>
    <DButton @action={{retry}} @label="my.retry" />
  </:error>
</DSelect>`;

  rowIconCode = `{{! Each option carries its own icon, so the row renders from the data rather
  than from a fixed adornment. }}
<DSelect
  @items={{this.levels}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @valueField="level"
  @labelField="title"
>
  <:item as |level|>
    <span class="my-row">
      {{icon level.icon}}
      <span class="my-details">
        <span class="my-primary">{{level.title}}</span>
        <span class="my-secondary">{{level.description}}</span>
      </span>
    </span>
  </:item>
</DSelect>`;

  chipIconCode = `{{! :item and :selection both render the glyph, so a chip looks like the row it
  came from. Keep the text in :selection — a chip's accessible name is built from
  it, and an icon-only chip is announced as a bare remove button. }}
<DSelect
  @items={{this.groups}}
  @multiple={{true}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @labelField="fullName"
>
  <:item as |group|>
    <span class="my-row">{{icon group.icon}}{{group.fullName}}</span>
  </:item>
  <:selection as |group|>
    <span class="my-chip">{{icon group.icon}}{{group.fullName}}</span>
  </:selection>
</DSelect>`;

  statusIconCode = `{{! A TRAILING glyph states something the row's text does not, so it needs a
  name of its own. A title attribute will not do it: focus sits on the option, not
  on the icon, so it is never announced. }}
<DSelect
  @items={{this.groups}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @labelField="fullName"
>
  <:item as |group|>
    <span class="my-row">
      <span class="my-primary">{{group.fullName}}</span>
      {{#if group.automatic}}
        <span class="my-status">
          {{icon "gear"}}
          <span class="sr-only">Managed automatically</span>
        </span>
      {{/if}}
    </span>
  </:item>
</DSelect>`;

  selectionCode = `{{! The SAME :selection block in both arities. On the single-select it is the
  resting trigger; on the multi-select it is each chip. Only the arity differs
  between these two invocations — the blocks are identical. }}
<DSelect
  @items={{this.people}}
  @value={{this.singleValue}}
  @onChange={{this.updateSingle}}
  @labelField="name"
>
  <:item as |person|>
    <span class="my-row">
      <img class="my-avatar" src={{person.avatar}} alt="" />
      <span class="my-details">
        <span class="my-primary">{{person.name}}</span>
        <span class="my-secondary">@{{person.username}}</span>
      </span>
    </span>
  </:item>

  {{! One line, because the trigger is one line — unlike :item, which has room for
  two. A chip's accessible name is built from this, so it must contain text. }}
  <:selection as |person|>
    <span class="my-chip">
      <img class="my-avatar --small" src={{person.avatar}} alt="" />
      {{person.name}}
    </span>
  </:selection>
</DSelect>

<DSelect
  @items={{this.people}}
  @multiple={{true}}
  @value={{this.multiValue}}
  @onChange={{this.updateMulti}}
  @labelField="name"
>
  <:item as |person|>
    <span class="my-row">
      <img class="my-avatar" src={{person.avatar}} alt="" />
      <span class="my-details">
        <span class="my-primary">{{person.name}}</span>
        <span class="my-secondary">@{{person.username}}</span>
      </span>
    </span>
  </:item>

  <:selection as |person|>
    <span class="my-chip">
      <img class="my-avatar --small" src={{person.avatar}} alt="" />
      {{person.name}}
    </span>
  </:selection>
</DSelect>`;

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
  <:item as |person|>
    <span class="my-row">
      <img class="my-avatar" src={{person.avatar}} alt="" />
      <span class="my-details">
        <span class="my-primary">{{person.name}}</span>
        <span class="my-secondary">@{{person.username}}</span>
      </span>
    </span>
  </:item>
</DSelect>`;

  footerCode = `{{! The footer is a SIBLING of the async content, not inside it, so it renders in
  every panel state: loading, populated, empty and failed. Gate its contents on
  what it is yielded rather than assuming there are rows.

  The example beside this uses three separate controls rather than one with a
  toggle, because a DSelect captures its source when its engine is built and it
  cannot be swapped underneath a live control. }}
<DSelect @load={{this.load}} @value={{this.value}} @onChange={{this.onChange}}>
  <:footer as |state|>
    {{#if state.loadedCount}}
      <span>{{state.loadedCount}} shown</span>
    {{else}}
      <span>Nothing to show</span>
    {{/if}}
    <DButton @action={{state.close}} @label="my.done" />
  </:footer>
</DSelect>`;

  pickerCode = `{{! Four blocks at once. Nothing new is needed to combine them: the header, the
  row, the compact chip and the footer each keep the contract they had alone. }}
<DSelect
  @items={{this.members}}
  @multiple={{true}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @groupBy="team"
  @groupLabel={{this.teamLabel}}
  @labelField="name"
>
  <:groupHeader as |group|>
    <span class="my-group-header">
      {{icon "users"}}
      {{group.label}}
    </span>
  </:groupHeader>

  <:item as |person|>
    <span class="my-row">
      <img class="my-avatar" src={{person.avatar}} alt="" />
      <span class="my-details">
        <span class="my-primary">{{person.name}}</span>
        <span class="my-secondary">
          {{if person.status person.status person.title}}
        </span>
      </span>
    </span>
  </:item>

  {{! The chip is one line while the row is two: the list has room for a second
  line and the trigger does not. A chip's accessible name is built from what
  this renders, so it has to contain text. }}
  <:selection as |person|>
    <span class="my-chip">
      <img class="my-avatar --small" src={{person.avatar}} alt="" />
      {{person.name}}
    </span>
  </:selection>

  {{! Gate on the yielded state rather than assuming rows: the footer renders in
  every panel state, including empty and failed. }}
  <:footer as |state|>
    <span class="my-footer-count">
      {{i18n "my.selected_count" count=state.value.length}}
    </span>
  </:footer>
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

  // The identity half of an async source: a loader answers "what matches this query", this
  // answers "what is this id". A select that reopens holding a value has only this to display
  // it. Synchronous, because the fixture is already in hand.
  //
  // The empty and always-failing sources below need no counterpart: nothing is ever selectable
  // from them, so they can never hold a value to resolve.
  get notificationLevels() {
    return notificationLevels();
  }

  @action
  resolvePerson(value) {
    return this.people.find((person) => person.id === value);
  }

  // The failure is the whole point of the card, so every open has to start from it. The fixture
  // exposes this precisely so the state is not a one-shot accident of request ordering.
  @action
  updateChipIcons(value) {
    this.chipIconsValue = value;
  }

  @action
  updateRowIcon(value) {
    this.rowIconValue = value;
  }

  @action
  updateStatus(value) {
    this.statusValue = value;
  }

  @action
  resetFailingLoader() {
    this.failingLoader.reset();
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
      <div class="select-examples__control">
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
      @title={{i18n "styleguide.sections.select.content.row_icon_example"}}
      @description={{i18n
        "styleguide.sections.select.content.row_icon_description"
      }}
      @tryThis={{i18n "styleguide.sections.select.content.row_icon_try_this"}}
      @code={{this.rowIconCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @identifier="sg-row-icons"
          @items={{this.notificationLevels}}
          @value={{this.rowIconValue}}
          @onChange={{this.updateRowIcon}}
          @valueField="level"
          @labelField="title"
        >
          <:item as |level|>
            <span class="select-examples__row">
              {{! Not aria-hidden: this glyph is the row's only distinguishing mark beyond its
              name, and the name already carries the meaning, so hiding it loses nothing while
              labelling it would say the same thing twice. }}
              {{dIcon level.icon}}
              <span class="select-examples__details">
                <span class="select-examples__primary">{{level.title}}</span>
                <span
                  class="select-examples__secondary"
                >{{level.description}}</span>
              </span>
            </span>
          </:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.content.chip_icon_example"}}
      @description={{i18n
        "styleguide.sections.select.content.chip_icon_description"
      }}
      @tryThis={{i18n "styleguide.sections.select.content.chip_icon_try_this"}}
      @code={{this.chipIconCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @identifier="sg-chip-icons"
          @items={{this.userGroups}}
          @multiple={{true}}
          @value={{this.chipIconsValue}}
          @onChange={{this.updateChipIcons}}
          @labelField="fullName"
        >
          <:item as |group|>
            <span class="select-examples__row">
              {{dIcon group.icon}}
              <span class="select-examples__primary">{{group.fullName}}</span>
            </span>
          </:item>
          {{! The chip's accessible name is built from whatever this renders, so the text has to
          stay: an icon-only chip is announced as a bare remove button. }}
          <:selection as |group|>
            <span class="select-examples__chip">
              {{dIcon group.icon}}
              {{group.fullName}}
            </span>
          </:selection>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.content.status_icon_example"}}
      @description={{i18n
        "styleguide.sections.select.content.status_icon_description"
      }}
      @tryThis={{i18n
        "styleguide.sections.select.content.status_icon_try_this"
      }}
      @code={{this.statusIconCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @identifier="sg-status-icons"
          @items={{this.userGroups}}
          @value={{this.statusValue}}
          @onChange={{this.updateStatus}}
          @labelField="fullName"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:item as |group|>
            <span class="select-examples__row">
              <span class="select-examples__primary">{{group.fullName}}</span>
              {{#if group.automatic}}
                {{! A trailing glyph carries meaning the row's text does not, so unlike a leading
                decorative icon it needs a name of its own — the visually hidden text, since a
                title on an icon inside an option is never announced. }}
                <span class="select-examples__status">
                  {{dIcon "gear"}}
                  <span class="sr-only">{{i18n
                      "styleguide.sections.select.content.status_icon_automatic"
                    }}</span>
                </span>
              {{/if}}
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
          @onClose={{this.resetFailingLoader}}
          @resolveValue={{this.resolvePerson}}
          @value={{this.errorValue}}
          @onChange={{this.updateError}}
          @variant="button"
          @labelField="name"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          {{! Contents only: the container and its alert role belong to the component, so a
          failure stays announced whatever this block renders. Retry is still yielded, so a
          block that wants its own recovery control can render one. }}
          <:error as |error retry|>
            <span class="select-examples__error-message">
              {{dIcon "triangle-exclamation"}}
              {{error.message}}
            </span>
            <DButton
              class="d-combobox__retry btn-flat"
              @action={{retry}}
              @label="styleguide.sections.select.content.error_retry"
            />
          </:error>
        </DSelect>
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
      class="--wide"
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
          <div class="select-examples__control">
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
      class="--wide"
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
            @resolveValue={{this.resolvePerson}}
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
      class="--wide"
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
