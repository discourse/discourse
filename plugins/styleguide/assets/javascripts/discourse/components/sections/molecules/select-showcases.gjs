import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dIconOrImage from "discourse/ui-kit/helpers/d-icon-or-image";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import {
  BADGES,
  categories,
  COLOR_SCHEMES,
  delay,
  EMOJI,
  notificationLevels,
  PEOPLE,
  REVIEWER_IDS,
  TAGS,
  USER_GROUPS,
} from "../../../lib/select-fixtures";
import StyleguideExample from "../../styleguide-example";

/**
 * The `pickers` group: the component doing real work.
 *
 * Every entry here is a job Discourse actually does, not a fixture that looks nice — that is the
 * rule that keeps this a gallery rather than a catalogue. Each one names, in its own copy, why
 * its blocks exist and what they buy; a picker whose rows the default label rendering could
 * express would not have blocks at all.
 */
export default class SelectShowcases extends Component {
  @service store;

  @tracked badgeValue = 3;
  @tracked categoryValue = "support";
  @tracked colorSchemeValue = "dark";
  @tracked emojiValue = "tada";
  @tracked groupValue = [11];
  @tracked notificationActionCount = 0;
  @tracked notificationValue = "watching";
  @tracked reviewerValue = REVIEWER_IDS;
  @tracked tagItems = TAGS;
  @tracked
  tagValue = [
    "design-system",
    "accessibility",
    "performance",
    "onboarding",
    "theming",
    "migrations",
  ];

  badges = BADGES;
  colorSchemes = COLOR_SCHEMES;
  emoji = EMOJI;
  people = PEOPLE;
  userGroups = USER_GROUPS;

  reviewerCode = `<DSelect
  @load={{this.loadReviewers}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @multiple={{true}}
  @resolveValues={{this.resolveReviewers}}
  @createUnresolvedItem={{this.unresolvedReviewer}}
  @labelField="username"
>
  {{! An avatar and a role are what tell two similar names apart. The chip stays
  one line, because the trigger is one line. }}
  <:selection as |person|>
    <span class="my-chip">
      {{#unless person.__unresolved}}
        <img class="my-avatar --small" src={{person.avatar}} alt="" />
      {{/unless}}
      {{person.username}}
    </span>
  </:selection>

  <:item as |person|>
    <span class="my-row">
      <img class="my-avatar" src={{person.avatar}} alt="" />
      <span class="my-details">
        <span class="my-primary">{{person.name}}</span>
        <span class="my-secondary">{{person.role}}</span>
      </span>
    </span>
  </:item>
</DSelect>`;

  categoryCode = `<DSelect
  @items={{this.categories}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
  @valueField="slug"
  @filterBy={{this.filterCategories}}
  @specialItems={{this.specialCategories}}
>
  {{! A category is a badge, not a string, and the badge carries its own topic
  count and restricted lock. The description is aria-hidden: it helps the eye
  choose, but it would double the length of every announced option. }}
  <:selection as |category|>{{categoryBadge category}}</:selection>

  <:item as |category|>
    <span class="my-category">
      <span class="my-category-status">
        {{categoryBadge category topicCount=category.topic_count readOnly=true}}
      </span>
      {{#if category.description_excerpt}}
        <span class="my-category-desc" aria-hidden="true">
          {{category.description_excerpt}}
        </span>
      {{/if}}
    </span>
  </:item>
</DSelect>`;

  tagCode = `<DSelect
  @items={{this.tagsSource}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @multiple={{true}}
  @variant="button"
  @valueField="slug"
  @labelField="label"
  @allowCreate={{this.allowCreateTag}}
  @createItem={{this.createTag}}
  @clearable={{true}}
>
  {{! The block earns its place on one row only: the create affordance, which
  swaps the tag icon for a plus and reads as an action rather than a result. }}
  <:item as |tag|>
    <span class="my-row">
      {{icon (if tag.__create "plus" "tag")}}
      <span class="my-primary">
        {{#if tag.__create}}
          {{i18n "my.create_tag" name=tag.label}}
        {{else}}
          {{tag.label}}
        {{/if}}
      </span>
      {{#unless tag.__create}}
        <span class="my-meta">{{tag.count}}</span>
      {{/unless}}
    </span>
  </:item>
</DSelect>`;

  notificationCode = `<DSelect
  @items={{this.notificationLevels}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="static"
  @valueField="level"
  @labelField="title"
>
  {{! Each level needs a sentence to be chosen correctly, and the icon is how
  the choice is recognised again later in the trigger. }}
  <:selection as |level|>
    <span class="my-chip">
      {{icon level.icon}}
      {{level.title}}
    </span>
  </:selection>

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

  colorSchemeCode = `{{! The clearest case for a block on the whole page: the value IS a colour,
  and no argument can render one. The swatches are aria-hidden because three
  unnamed chips convey nothing; the scheme's name already identifies it. }}
<DSelect
  @items={{this.schemes}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @valueField="id"
  @labelField="name"
>
  <:item as |scheme|>
  <span class="select-examples__row select-examples__row--glyph">
    <span class="select-showcases__swatches" aria-hidden="true">
      {{#each scheme.swatches as |swatch|}}
        <span class="select-showcases__swatch" style={{swatch}}></span>
      {{/each}}
    </span>
      <span class="my-primary">{{scheme.name}}</span>
    </span>
  </:item>
</DSelect>`;

  emojiCode = `<DSelect
  @items={{this.emoji}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @groupBy="group"
  @valueField="name"
  @labelField="name"
>
  {{! The glyph is the point, and the shortcode is what the reader will type,
  so it belongs in the row in monospace rather than only in a tooltip. }}
  <:item as |item|>
    <span class="select-examples__row select-examples__row--glyph">
      {{dEmoji item.name}}
      <span class="select-examples__primary">{{item.name}}</span>
      <code class="select-showcases__shortcode">:{{item.name}}:</code>
    </span>
  </:item>
</DSelect>`;

  groupCode = `{{! A trailing pill rather than trailing text: "Automatic" is a property of the
  group, not a measurement of it, so it should not read as a number. }}
<DSelect
  @items={{this.groups}}
  @multiple={{true}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @valueField="name"
  @labelField="fullName"
>
  <:item as |group|>
  <span class="select-examples__row select-examples__row--glyph">
    {{dIcon group.icon}}
    <span class="select-examples__primary">{{group.fullName}}</span>
    {{#if group.automatic}}
      <span class="select-showcases__pill">Automatic</span>
    {{/if}}
      <span class="my-meta">{{group.memberLabel}}</span>
    </span>
  </:item>
</DSelect>`;

  badgeCode = `{{! The icon-or-image helper takes a badge directly and renders either an icon or
  an image with an empty alt, so the row needs no image handling of its own.
  Rarity drives the colour, and position carries it too. }}
<DSelect
  @items={{this.badges}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @valueField="id"
  @labelField="name"
>
  <:item as |badge|>
  <span class="select-examples__row select-examples__row--glyph">
    <span class="select-showcases__badge-icon --{{badge.rarity}}">
      {{dIconOrImage badge}}
    </span>
    <span class="select-examples__primary">{{badge.name}}</span>
      <span class="my-meta">{{badge.grantLabel}}</span>
    </span>
  </:item>
</DSelect>`;

  @cached
  get categories() {
    return categories(this.store);
  }

  get badgeItems() {
    return this.badges.map((badge) => ({
      ...badge,
      grantLabel: i18n("styleguide.sections.select.pickers.badges.granted", {
        count: badge.grantCount,
      }),
    }));
  }

  get colorSchemeItems() {
    return this.colorSchemes.map((scheme) => ({
      ...scheme,
      swatches: scheme.colors.map((color) =>
        trustHTML(`--swatch-color: #${color}`)
      ),
    }));
  }

  get groupItems() {
    return this.userGroups.map((group) => ({
      ...group,
      memberLabel: i18n("styleguide.sections.select.pickers.groups.members", {
        count: group.memberCount,
      }),
    }));
  }

  get notificationEvent() {
    if (this.notificationActionCount > 0) {
      return i18n(
        "styleguide.sections.select.pickers.notifications.action_count",
        { count: this.notificationActionCount }
      );
    }

    return i18n("styleguide.sections.select.pickers.notifications.event_idle");
  }

  get notificationItems() {
    return notificationLevels(this.manageNotifications);
  }

  @action
  allowCreateTag(filter, items) {
    const slug = this.#tagSlug(filter);
    return (
      slug.length > 0 && !items.some((item) => item.slug.toLowerCase() === slug)
    );
  }

  @action
  createTag(filter) {
    const label = filter.trim();
    return {
      __create: true,
      label,
      slug: this.#tagSlug(label),
    };
  }

  @action
  filterCategories(category, filter) {
    const searchable = `${category.name} ${category.description_excerpt ?? ""}`;
    return searchable.toLowerCase().includes(filter.toLowerCase());
  }

  @action
  async loadReviewers(filter, { signal }) {
    await delay(signal, 650);
    const normalizedFilter = filter.toLowerCase();
    return this.people.filter((person) =>
      `${person.name} ${person.username} ${person.title ?? ""}`
        .toLowerCase()
        .includes(normalizedFilter)
    );
  }

  @action
  manageNotifications() {
    this.notificationActionCount++;
  }

  @action
  async resolveReviewers(values, { signal }) {
    await delay(signal, 500);
    return this.people.filter((person) => values.includes(person.id));
  }

  @action
  specialCategories() {
    // A real Category record, not a bare object: the badge renderer reads model fields, so a
    // plain hash would render an empty badge.
    return [
      this.store.createRecord("category", {
        id: 0,
        name: i18n(
          "styleguide.sections.select.pickers.categories.uncategorized"
        ),
        slug: "uncategorized",
        color: "0088CC",
        description_excerpt: i18n(
          "styleguide.sections.select.pickers.categories.uncategorized_description"
        ),
        topic_count: 19,
      }),
    ];
  }

  @action
  tagsSource() {
    return this.tagItems;
  }

  @action
  unresolvedReviewer(value) {
    return {
      id: value,
      name: i18n("styleguide.sections.select.pickers.reviewers.deleted_name"),
      title: i18n(
        "styleguide.sections.select.pickers.reviewers.deleted_description"
      ),
      username: i18n(
        "styleguide.sections.select.pickers.reviewers.deleted_username"
      ),
    };
  }

  @action
  updateBadge(value) {
    this.badgeValue = value;
  }

  @action
  updateCategory(value) {
    this.categoryValue = value;
  }

  @action
  updateColorScheme(value) {
    this.colorSchemeValue = value;
  }

  @action
  updateEmoji(value) {
    this.emojiValue = value;
  }

  @action
  updateGroup(value) {
    this.groupValue = value;
  }

  @action
  updateNotification(value) {
    this.notificationValue = value;
  }

  @action
  updateReviewers(value) {
    this.reviewerValue = value;
  }

  @action
  updateTags(value, items) {
    this.tagValue = value;
    const createdTags = items.filter(
      (item) => item.__create && !this.tagItems.includes(item)
    );
    if (createdTags.length > 0) {
      this.tagItems = [...this.tagItems, ...createdTags];
    }
  }

  #tagSlug(label) {
    return label
      .trim()
      .toLowerCase()
      .replaceAll(/[^a-z0-9]+/g, "-")
      .replaceAll(/(^-|-$)/g, "");
  }

  <template>
    {{! No intro paragraph: the group's own description already states what this group is for,
    and repeating it here put the same claim on screen twice. }}
    <StyleguideExample
      @title={{i18n "styleguide.sections.select.pickers.reviewers.title"}}
      @description={{i18n
        "styleguide.sections.select.pickers.reviewers.description"
      }}
      @tryThis={{i18n "styleguide.sections.select.pickers.reviewers.try_this"}}
      @code={{this.reviewerCode}}
    >
      <div
        class="select-showcases__control"
        data-test-select-showcase="reviewers"
      >
        <DSelect
          @identifier="sg-reviewers"
          @load={{this.loadReviewers}}
          @value={{this.reviewerValue}}
          @onChange={{this.updateReviewers}}
          @multiple={{true}}
          @resolveValues={{this.resolveReviewers}}
          @createUnresolvedItem={{this.unresolvedReviewer}}
          @labelField="username"
          @placeholder={{i18n
            "styleguide.sections.select.pickers.reviewers.placeholder"
          }}
        >
          <:selection as |person|>
            <span class="select-examples__row select-examples__row--glyph">
              {{#unless person.__unresolved}}
                <img
                  class="select-examples__avatar --small"
                  src={{person.avatar}}
                  alt=""
                />
              {{/unless}}
              {{person.username}}
            </span>
          </:selection>
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
                  @{{person.username}}{{#if person.title}}
                    ·
                    {{person.title}}
                  {{/if}}
                </span>
              </span>
            </span>
          </:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.pickers.categories.title"}}
      @description={{i18n
        "styleguide.sections.select.pickers.categories.description"
      }}
      @tryThis={{i18n "styleguide.sections.select.pickers.categories.try_this"}}
      @code={{this.categoryCode}}
    >
      <div
        class="select-showcases__control"
        data-test-select-showcase="categories"
      >
        <DSelect
          @identifier="sg-categories"
          @items={{this.categories}}
          @value={{this.categoryValue}}
          @onChange={{this.updateCategory}}
          @variant="button"
          @valueField="slug"
          @filterBy={{this.filterCategories}}
          @specialItems={{this.specialCategories}}
          @placeholder={{i18n
            "styleguide.sections.select.pickers.categories.placeholder"
          }}
        >
          <:selection as |category|>
            {{dCategoryBadge category}}
          </:selection>
          {{! Shaped like core's own category row: the badge and its counts on one line, the
            description below. The description is aria-hidden because the badge already names
            the option, and repeating a full sentence after every row makes the list slower to
            navigate by ear than by eye. }}
          <:item as |category|>
            <span class="select-showcases__category">
              <span class="select-showcases__category-status">
                {{dCategoryBadge
                  category
                  topicCount=category.topic_count
                  readOnly=category.read_restricted
                }}
              </span>
              {{#if category.description_excerpt}}
                <span
                  class="select-showcases__category-desc"
                  aria-hidden="true"
                >
                  {{category.description_excerpt}}
                </span>
              {{/if}}
            </span>
          </:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.pickers.tags.title"}}
      @description={{i18n
        "styleguide.sections.select.pickers.tags.description"
      }}
      @tryThis={{i18n "styleguide.sections.select.pickers.tags.try_this"}}
      @code={{this.tagCode}}
    >
      <div class="select-showcases__control" data-test-select-showcase="tags">
        <DSelect
          @identifier="sg-tags"
          @items={{this.tagsSource}}
          @value={{this.tagValue}}
          @onChange={{this.updateTags}}
          @multiple={{true}}
          @variant="button"
          @valueField="slug"
          @labelField="label"
          @allowCreate={{this.allowCreateTag}}
          @createItem={{this.createTag}}
          @clearable={{true}}
          @placeholder={{i18n
            "styleguide.sections.select.pickers.tags.placeholder"
          }}
          @searchPlaceholder={{i18n
            "styleguide.sections.select.pickers.tags.search_placeholder"
          }}
        >
          {{! The only reason this block exists: the create row has to read as an action, not
            as an existing tag. Every other row is the default label. }}
          <:item as |tag|>
            <span class="select-examples__row select-examples__row--glyph">
              {{dIcon (if tag.__create "plus" "tag")}}
              <span class="select-examples__primary">
                {{#if tag.__create}}
                  {{i18n
                    "styleguide.sections.select.pickers.tags.create"
                    tag=tag.label
                  }}
                {{else}}
                  {{tag.label}}
                {{/if}}
              </span>
              {{#unless tag.__create}}
                <span class="select-examples__meta">{{tag.count}}</span>
              {{/unless}}
            </span>
          </:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.pickers.notifications.title"}}
      @description={{i18n
        "styleguide.sections.select.pickers.notifications.description"
      }}
      @tryThis={{i18n
        "styleguide.sections.select.pickers.notifications.try_this"
      }}
      @code={{this.notificationCode}}
      data-test-select-showcase="notifications"
    >
      <:default>
        <div class="select-showcases__control">
          <DSelect
            @identifier="sg-notifications"
            @items={{this.notificationItems}}
            @value={{this.notificationValue}}
            @onChange={{this.updateNotification}}
            @variant="static"
            @valueField="level"
            @labelField="title"
          >
            <:selection as |level|>
              <span class="select-examples__row select-examples__row--glyph">
                {{dIcon level.icon}}
                {{level.title}}
              </span>
            </:selection>
            <:item as |level|>
              <span class="select-examples__row select-examples__row--identity">
                {{dIcon level.icon}}
                <span class="select-examples__details">
                  <span class="select-examples__primary">{{level.title}}</span>
                  <span class="select-examples__secondary">
                    {{level.description}}
                  </span>
                </span>
              </span>
            </:item>
          </DSelect>
        </div>
      </:default>
      <:result>
        <span data-test-notification-event>{{this.notificationEvent}}</span>
      </:result>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.pickers.colors.title"}}
      @description={{i18n
        "styleguide.sections.select.pickers.colors.description"
      }}
      @tryThis={{i18n "styleguide.sections.select.pickers.colors.try_this"}}
      @code={{this.colorSchemeCode}}
    >
      <div class="select-showcases__control">
        <DSelect
          @identifier="sg-colors"
          @items={{this.colorSchemeItems}}
          @value={{this.colorSchemeValue}}
          @onChange={{this.updateColorScheme}}
          @variant="button"
        >
          <:selection as |scheme|>
            <span class="select-examples__row select-examples__row--glyph">
              <span class="select-showcases__swatches" aria-hidden="true">
                {{#each scheme.swatches key="@index" as |swatch|}}
                  <span
                    class="select-showcases__swatch"
                    style={{swatch}}
                  ></span>
                {{/each}}
              </span>
              {{scheme.name}}
            </span>
          </:selection>
          {{! The swatches are aria-hidden: they are the value made visible, but a screen
            reader gets nothing from three unnamed colour chips, and the name already
            identifies the scheme. }}
          <:item as |scheme|>
            <span class="select-examples__row select-examples__row--glyph">
              <span class="select-showcases__swatches" aria-hidden="true">
                {{#each scheme.swatches key="@index" as |swatch|}}
                  <span
                    class="select-showcases__swatch"
                    style={{swatch}}
                  ></span>
                {{/each}}
              </span>
              <span class="select-examples__primary">{{scheme.name}}</span>
            </span>
          </:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.pickers.emoji.title"}}
      @description={{i18n
        "styleguide.sections.select.pickers.emoji.description"
      }}
      @tryThis={{i18n "styleguide.sections.select.pickers.emoji.try_this"}}
      @code={{this.emojiCode}}
    >
      <div class="select-showcases__control">
        <DSelect
          @identifier="sg-emoji"
          @items={{this.emoji}}
          @value={{this.emojiValue}}
          @onChange={{this.updateEmoji}}
          @groupBy="group"
          @variant="button"
        >
          <:selection as |item|>
            <span class="select-examples__row select-examples__row--glyph">
              {{dEmoji item.name}}
              {{item.name}}
            </span>
          </:selection>
          <:item as |item|>
            <span class="select-examples__row select-examples__row--glyph">
              {{dEmoji item.name}}
              <span class="select-examples__primary">{{item.name}}</span>
              {{! The shortcode is what a reader types, so it is shown rather than hidden in
                a tooltip. Hidden from the announcement because it repeats the name. }}
              <code class="select-showcases__shortcode" aria-hidden="true">
                :{{item.name}}:
              </code>
            </span>
          </:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.pickers.groups.title"}}
      @description={{i18n
        "styleguide.sections.select.pickers.groups.description"
      }}
      @tryThis={{i18n "styleguide.sections.select.pickers.groups.try_this"}}
      @code={{this.groupCode}}
    >
      <div class="select-showcases__control">
        <DSelect
          @identifier="sg-groups"
          @items={{this.groupItems}}
          @value={{this.groupValue}}
          @onChange={{this.updateGroup}}
          @multiple={{true}}
          @labelField="fullName"
          @placeholder={{i18n
            "styleguide.sections.select.pickers.groups.placeholder"
          }}
        >
          <:item as |group|>
            <span class="select-examples__row select-examples__row--glyph">
              {{dIcon group.icon}}
              <span class="select-examples__primary">{{group.fullName}}</span>
              {{#if group.automatic}}
                <span class="select-showcases__pill">
                  {{i18n "styleguide.sections.select.pickers.groups.automatic"}}
                </span>
              {{/if}}
              <span class="select-examples__meta">{{group.memberLabel}}</span>
            </span>
          </:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.pickers.badges.title"}}
      @description={{i18n
        "styleguide.sections.select.pickers.badges.description"
      }}
      @tryThis={{i18n "styleguide.sections.select.pickers.badges.try_this"}}
      @code={{this.badgeCode}}
    >
      <div class="select-showcases__control">
        <DSelect
          @identifier="sg-badges"
          @items={{this.badgeItems}}
          @value={{this.badgeValue}}
          @onChange={{this.updateBadge}}
          @variant="button"
        >
          <:selection as |badge|>
            <span class="select-examples__row select-examples__row--glyph">
              <span
                class="select-showcases__badge-icon --{{badge.rarity}}"
              >{{dIconOrImage badge}}</span>
              {{badge.name}}
            </span>
          </:selection>
          <:item as |badge|>
            <span class="select-examples__row select-examples__row--glyph">
              <span
                class="select-showcases__badge-icon --{{badge.rarity}}"
              >{{dIconOrImage badge}}</span>
              <span class="select-examples__primary">{{badge.name}}</span>
              <span class="select-examples__meta">{{badge.grantLabel}}</span>
            </span>
          </:item>
        </DSelect>
      </div>
    </StyleguideExample>
  </template>
}
