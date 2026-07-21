import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import StyleguideExample from "../../styleguide-example";

const REVIEWER_IDS = [101, 102, 103, 104, 105, 106, 999];

export default class SelectShowcases extends Component {
  @tracked categoryValue = "vegetables";
  @tracked notificationActionCount = 0;
  @tracked notificationValue = "watching";
  @tracked reviewerValue = REVIEWER_IDS;
  @tracked
  tagItems = [
    { slug: "accessibility", label: "accessibility" },
    { slug: "design", label: "design" },
    { slug: "documentation", label: "documentation" },
    { slug: "performance", label: "performance" },
    { slug: "release-notes", label: "release-notes" },
    { slug: "security", label: "security" },
    { slug: "support", label: "support" },
    { slug: "ux", label: "ux" },
  ];
  @tracked
  tagValue = [
    "accessibility",
    "design",
    "documentation",
    "performance",
    "release-notes",
    "security",
  ];

  reviewers = [
    {
      id: 101,
      avatar_template: "/images/avatar.png",
      name: "Maya Chen",
      role: i18n("styleguide.sections.select.showcases.reviewer_roles.design"),
      username: "maya",
    },
    {
      id: 102,
      avatar_template: "/images/avatar.png",
      name: "Alex Rivera",
      role: i18n(
        "styleguide.sections.select.showcases.reviewer_roles.frontend"
      ),
      username: "alex-rivera",
    },
    {
      id: 103,
      avatar_template: "/images/avatar.png",
      name: "Priya Shah",
      role: i18n(
        "styleguide.sections.select.showcases.reviewer_roles.accessibility"
      ),
      username: "priya-shah",
    },
    {
      id: 104,
      avatar_template: "/images/avatar.png",
      name: "Jordan Lee",
      role: i18n(
        "styleguide.sections.select.showcases.reviewer_roles.security"
      ),
      username: "jordan-lee",
    },
    {
      id: 105,
      avatar_template: "/images/avatar.png",
      name: "Sam Wilson",
      role: i18n(
        "styleguide.sections.select.showcases.reviewer_roles.performance"
      ),
      username: "sam-wilson",
    },
    {
      id: 106,
      avatar_template: "/images/avatar.png",
      name: "Morgan Taylor",
      role: i18n(
        "styleguide.sections.select.showcases.reviewer_roles.documentation"
      ),
      username: "morgan-taylor",
    },
    {
      id: 107,
      avatar_template: "/images/avatar.png",
      disabled: true,
      name: "Taylor Kim",
      role: i18n(
        "styleguide.sections.select.showcases.reviewer_roles.unavailable"
      ),
      username: "taylor-kim",
    },
  ];

  categoryCode = `<DSelect
  @items={{this.categories}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
  @valueField="slug"
  @filterBy={{this.filterCategories}}
  @specialItems={{this.specialCategories}}
  @selectedIcon="star"
>
  <:selection as |category|>…</:selection>
  <:item as |category|>…</:item>
</DSelect>`;

  notificationCode = `<DSelect
  @items={{this.notificationLevels}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="static"
  @valueField="level"
  @labelField="title"
>
  <:selection as |level|>…</:selection>
  <:item as |level|>…</:item>
</DSelect>`;

  reviewerCode = `<DSelect
  @load={{this.loadReviewers}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @multiple={{true}}
  @selected={{this.seededReviewer}}
  @resolveValues={{this.resolveReviewers}}
  @createUnresolvedItem={{this.unresolvedReviewer}}
  @labelField="username"
>
  <:selection as |user|>…</:selection>
  <:item as |user|>…</:item>
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
  <:selection as |tag|>…</:selection>
  <:item as |tag|>…</:item>
</DSelect>`;

  get categories() {
    return this.args.categories.map((category, index) => ({
      color: category.color,
      description_excerpt: category.description_excerpt,
      id: category.id,
      name: category.name,
      read_restricted: category.read_restricted,
      slug: category.slug,
      topic_count: [128, 76, 34][index],
    }));
  }

  get notificationEvent() {
    if (this.notificationActionCount > 0) {
      return i18n(
        "styleguide.sections.select.showcases.notifications.action_count",
        { count: this.notificationActionCount }
      );
    }

    return i18n(
      "styleguide.sections.select.showcases.notifications.event_idle"
    );
  }

  get notificationItems() {
    return [
      {
        description: i18n(
          "styleguide.sections.select.showcases.notifications.muted_description"
        ),
        icon: "bell-slash",
        level: "muted",
        title: i18n("styleguide.sections.select.showcases.notifications.muted"),
      },
      {
        description: i18n(
          "styleguide.sections.select.showcases.notifications.normal_description"
        ),
        icon: "bell",
        level: "normal",
        title: i18n(
          "styleguide.sections.select.showcases.notifications.normal"
        ),
      },
      {
        description: i18n(
          "styleguide.sections.select.showcases.notifications.tracking_description"
        ),
        icon: "circle-dot",
        level: "tracking",
        title: i18n(
          "styleguide.sections.select.showcases.notifications.tracking"
        ),
      },
      {
        description: i18n(
          "styleguide.sections.select.showcases.notifications.watching_description"
        ),
        icon: "bell",
        level: "watching",
        title: i18n(
          "styleguide.sections.select.showcases.notifications.watching"
        ),
      },
      {
        description: i18n(
          "styleguide.sections.select.showcases.notifications.mentions_description"
        ),
        disabled: true,
        icon: "at",
        level: "mentions",
        title: i18n(
          "styleguide.sections.select.showcases.notifications.mentions"
        ),
      },
      {
        description: i18n(
          "styleguide.sections.select.showcases.notifications.manage_description"
        ),
        icon: "gear",
        level: "manage",
        onSelect: this.manageNotifications,
        title: i18n(
          "styleguide.sections.select.showcases.notifications.manage"
        ),
      },
    ];
  }

  get seededReviewer() {
    return this.reviewers[0];
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
    const searchable = `${category.name} ${category.description_excerpt}`;
    return searchable.toLowerCase().includes(filter.toLowerCase());
  }

  @action
  async loadReviewers(filter, { signal }) {
    await this.#delay(signal, 650);
    const normalizedFilter = filter.toLowerCase();
    return this.reviewers.filter((reviewer) =>
      `${reviewer.name} ${reviewer.username} ${reviewer.role}`
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
    await this.#delay(signal, 500);
    return this.reviewers.filter((reviewer) => values.includes(reviewer.id));
  }

  @action
  specialCategories() {
    return [
      {
        description_excerpt: i18n(
          "styleguide.sections.select.showcases.categories.uncategorized_description"
        ),
        isUncategorized: true,
        name: i18n(
          "styleguide.sections.select.showcases.categories.uncategorized"
        ),
        slug: "uncategorized",
        topic_count: 19,
      },
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
      name: i18n("styleguide.sections.select.showcases.reviewers.deleted_name"),
      role: i18n(
        "styleguide.sections.select.showcases.reviewers.deleted_description"
      ),
      username: i18n(
        "styleguide.sections.select.showcases.reviewers.deleted_username"
      ),
    };
  }

  @action
  updateCategory(value) {
    this.categoryValue = value;
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

  #delay(signal, milliseconds) {
    return new Promise((resolve, reject) => {
      const onAbort = () => {
        clearTimeout(timeout);
        reject(signal.reason ?? new DOMException("Aborted", "AbortError"));
      };
      const timeout = setTimeout(() => {
        signal.removeEventListener("abort", onAbort);
        resolve();
      }, milliseconds);

      if (signal.aborted) {
        onAbort();
      } else {
        signal.addEventListener("abort", onAbort, { once: true });
      }
    });
  }

  #tagSlug(label) {
    return label
      .trim()
      .toLowerCase()
      .replaceAll(/[^a-z0-9]+/g, "-")
      .replaceAll(/(^-|-$)/g, "");
  }

  <template>
    <section class="select-showcases">
      <h2 class="select-showcases__title">
        {{i18n "styleguide.sections.select.showcases.title"}}
      </h2>
      <p class="section-description">
        {{i18n "styleguide.sections.select.showcases.description"}}
      </p>

      <StyleguideExample
        @title={{i18n "styleguide.sections.select.showcases.reviewers.title"}}
        @code={{this.reviewerCode}}
      >
        <div
          class="select-showcases__control --reviewers"
          data-test-select-showcase="reviewers"
        >
          <DSelect
            @load={{this.loadReviewers}}
            @multiple={{true}}
            @value={{this.reviewerValue}}
            @onChange={{this.updateReviewers}}
            @selected={{this.seededReviewer}}
            @resolveValues={{this.resolveReviewers}}
            @createUnresolvedItem={{this.unresolvedReviewer}}
            @labelField="username"
            @placeholder={{i18n
              "styleguide.sections.select.showcases.reviewers.placeholder"
            }}
          >
            <:selection as |reviewer|>
              <span class="select-showcases__reviewer-selection">
                {{#unless reviewer.__unresolved}}
                  {{dAvatar reviewer imageSize="tiny" hideTitle=true}}
                {{/unless}}
                <span>{{reviewer.username}}</span>
              </span>
            </:selection>
            <:item as |reviewer|>
              <span class="select-showcases__reviewer">
                {{dAvatar reviewer imageSize="small" hideTitle=true}}
                <span class="select-showcases__details">
                  <span class="select-showcases__primary">
                    {{reviewer.name}}
                  </span>
                  <span class="select-showcases__secondary">
                    @{{reviewer.username}}
                    ·
                    {{reviewer.role}}
                  </span>
                </span>
              </span>
            </:item>
          </DSelect>
        </div>
      </StyleguideExample>

      <StyleguideExample
        @title={{i18n "styleguide.sections.select.showcases.categories.title"}}
        @code={{this.categoryCode}}
      >
        <div
          class="select-showcases__control --categories"
          data-test-select-showcase="categories"
        >
          <DSelect
            @items={{this.categories}}
            @value={{this.categoryValue}}
            @onChange={{this.updateCategory}}
            @variant="button"
            @valueField="slug"
            @filterBy={{this.filterCategories}}
            @specialItems={{this.specialCategories}}
            @selectedIcon="star"
            @placeholder={{i18n
              "styleguide.sections.select.showcases.categories.placeholder"
            }}
          >
            <:selection as |category|>
              {{#if category.isUncategorized}}
                <span class="select-showcases__category-selection">
                  {{dIcon "inbox"}}
                  <span>{{category.name}}</span>
                </span>
              {{else}}
                {{dCategoryBadge category categoryStyle="bullet"}}
              {{/if}}
            </:selection>
            <:item as |category|>
              <span class="select-showcases__category">
                <span class="select-showcases__category-selection">
                  {{#if category.isUncategorized}}
                    {{dIcon "inbox"}}
                    <span>{{category.name}}</span>
                  {{else}}
                    {{dCategoryBadge category categoryStyle="bullet"}}
                  {{/if}}
                </span>
                <span class="select-showcases__details">
                  <span class="select-showcases__secondary">
                    {{category.description_excerpt}}
                  </span>
                  <span class="select-showcases__meta">
                    {{i18n
                      "styleguide.sections.select.showcases.categories.topic_count"
                      count=category.topic_count
                    }}
                  </span>
                </span>
              </span>
            </:item>
          </DSelect>
        </div>
      </StyleguideExample>

      <StyleguideExample
        @title={{i18n "styleguide.sections.select.showcases.tags.title"}}
        @code={{this.tagCode}}
      >
        <div
          class="select-showcases__control --tags"
          data-test-select-showcase="tags"
        >
          <DSelect
            @items={{this.tagsSource}}
            @multiple={{true}}
            @value={{this.tagValue}}
            @onChange={{this.updateTags}}
            @variant="button"
            @valueField="slug"
            @labelField="label"
            @allowCreate={{this.allowCreateTag}}
            @createItem={{this.createTag}}
            @clearable={{true}}
            @placeholder={{i18n
              "styleguide.sections.select.showcases.tags.placeholder"
            }}
            @searchPlaceholder={{i18n
              "styleguide.sections.select.showcases.tags.search_placeholder"
            }}
          >
            <:selection as |tag|>
              <span class="select-showcases__tag">
                {{dIcon "tag"}}
                <span>{{tag.label}}</span>
              </span>
            </:selection>
            <:item as |tag|>
              <span class="select-showcases__tag-row">
                {{dIcon (if tag.__create "plus" "tag")}}
                <span>
                  {{#if tag.__create}}
                    {{i18n
                      "styleguide.sections.select.showcases.tags.create"
                      tag=tag.label
                    }}
                  {{else}}
                    {{tag.label}}
                  {{/if}}
                </span>
              </span>
            </:item>
          </DSelect>
        </div>
      </StyleguideExample>

      <StyleguideExample
        @title={{i18n
          "styleguide.sections.select.showcases.notifications.title"
        }}
        @code={{this.notificationCode}}
      >
        <div
          class="select-showcases__control --notifications"
          data-test-select-showcase="notifications"
        >
          <DSelect
            @items={{this.notificationItems}}
            @value={{this.notificationValue}}
            @onChange={{this.updateNotification}}
            @variant="static"
            @valueField="level"
            @labelField="title"
            @placeholder={{i18n
              "styleguide.sections.select.showcases.notifications.placeholder"
            }}
          >
            <:selection as |level|>
              <span class="select-showcases__notification-selection">
                {{dIcon level.icon}}
                <span>{{level.title}}</span>
              </span>
            </:selection>
            <:item as |level|>
              <span class="select-showcases__notification">
                {{dIcon level.icon}}
                <span class="select-showcases__details">
                  <span class="select-showcases__primary">{{level.title}}</span>
                  <span class="select-showcases__secondary">
                    {{level.description}}
                  </span>
                </span>
              </span>
            </:item>
          </DSelect>
          <p class="styleguide-note" data-test-notification-event>
            {{this.notificationEvent}}
          </p>
        </div>
      </StyleguideExample>
    </section>
  </template>
}
