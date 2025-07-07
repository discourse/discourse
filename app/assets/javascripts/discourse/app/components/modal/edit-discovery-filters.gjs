import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { includes, lt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import TextField from "discourse/components/text-field";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import I18n, { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";
import ComboBox from "select-kit/components/combo-box";
import TagChooser from "select-kit/components/tag-chooser";

export default class EditDiscoveryFilters extends Component {
  @service router;
  @service currentUser;

  @tracked filteredCategories = [];
  @tracked filteredTags = [];
  @tracked excludedCategories = [];
  @tracked excludedTags = [];
  @tracked sortOrders = [];
  @tracked statusFilters = [];
  @tracked activityFilters = {};
  @tracked createdFilters = {};
  @tracked postCountFilters = {};
  @tracked viewCountFilters = {};
  @tracked likeCountFilters = {};
  @tracked posterCountFilters = {};

  constructor() {
    super(...arguments);
    this.parseExistingFilters();
  }

  parseExistingFilters() {
    console.log(this.args.model.filterString);
    if (!this.args.model.filterString) {
      return;
    }

    const filters = this.args.model.filterString.split(" ");

    filters.forEach((filter) => {
      const match = filter.match(/^(-)?([^:]+):(.+)$/);
      if (!match) {
        return;
      }

      const [, prefix, key, value] = match;
      const isExclude = prefix === "-";

      switch (key) {
        case "category":
          const categories = value
            .split(",")
            .map((slug) => {
              const category = Category.findBySlug(slug);
              return category
                ? { id: category.id, slug, name: category.name }
                : null;
            })
            .filter(Boolean);

          if (isExclude) {
            this.excludedCategories = categories;
          } else {
            this.filteredCategories = categories;
          }
          break;

        case "tag":
          const tags = value.split(",");
          if (isExclude) {
            this.excludedTags = tags;
          } else {
            this.filteredTags = tags;
          }
          break;

        case "order":
          this.sortOrders = value.split(",").map((order) => {
            const isAscending = order.endsWith("-asc");
            const innerKey = isAscending ? order.replace("-asc", "") : order;
            return { key: innerKey, direction: isAscending ? "asc" : "desc" };
          });
          break;

        case "status":
          this.statusFilters = value.split(",");
          break;

        case "activity-before":
          this.activityFilters.before = value;
          break;
        case "activity-after":
          this.activityFilters.after = value;
          break;

        case "created-before":
          this.createdFilters.before = value;
          break;
        case "created-after":
          this.createdFilters.after = value;
          break;

        case "posts-min":
          this.postCountFilters.min = value;
          break;
        case "posts-max":
          this.postCountFilters.max = value;
          break;

        case "views-min":
          this.viewCountFilters.min = value;
          break;
        case "views-max":
          this.viewCountFilters.max = value;
          break;

        case "likes-min":
          this.likeCountFilters.min = value;
          break;
        case "likes-max":
          this.likeCountFilters.max = value;
          break;

        case "posters-min":
          this.posterCountFilters.min = value;
          break;
        case "posters-max":
          this.posterCountFilters.max = value;
          break;
      }
    });
  }

  get availableSortOrders() {
    return [
      { id: "activity", name: i18n("topic.filters.sort_by.activity") },
      { id: "category", name: i18n("topic.filters.sort_by.category") },
      { id: "created", name: i18n("topic.filters.sort_by.created") },
      { id: "latest-post", name: i18n("topic.filters.sort_by.latest_post") },
      { id: "likes", name: i18n("topic.filters.sort_by.likes") },
      { id: "likes-op", name: i18n("topic.filters.sort_by.op_likes") },
      { id: "posters", name: i18n("topic.filters.sort_by.posters") },
      { id: "title", name: i18n("topic.filters.sort_by.title") },
      { id: "views", name: i18n("topic.filters.sort_by.views") },
      { id: "read", name: i18n("topic.filters.sort_by.read") },
    ];
  }

  get availableStatusFilters() {
    return [
      { id: "open", name: i18n("topic.filters.status.open") },
      { id: "closed", name: i18n("topic.filters.status.closed") },
      { id: "archived", name: i18n("topic.filters.status.archived") },
      { id: "listed", name: i18n("topic.filters.status.listed") },
      { id: "unlisted", name: i18n("topic.filters.status.unlisted") },
      { id: "pinned", name: i18n("topic.filters.status.pinned") },
      { id: "bookmarked", name: i18n("topic.filters.status.bookmarked") },
    ];
  }

  @action
  addSortOrder() {
    this.sortOrders = [
      ...this.sortOrders,
      { key: "activity", direction: "desc" },
    ];
  }

  @action
  removeSortOrder(index) {
    this.sortOrders = this.sortOrders.filter((_, i) => i !== index);
  }

  @action
  updateSortOrder(index, field, value) {
    const updated = [...this.sortOrders];
    updated[index] = { ...updated[index], [field]: value };
    this.sortOrders = updated;
  }

  @action
  toggleStatusFilter(status) {
    if (this.statusFilters.includes(status)) {
      this.statusFilters = this.statusFilters.filter((s) => s !== status);
    } else {
      this.statusFilters = [...this.statusFilters, status];
    }
  }

  @action
  updateCategories(categories) {
    this.filteredCategories = categories.map((c) => ({
      id: c.id,
      slug: c.slug,
      name: c.name,
    }));
  }

  @action
  updateExcludedCategories(categories) {
    this.excludedCategories = categories.map((c) => ({
      id: c.id,
      slug: c.slug,
      name: c.name,
    }));
  }

  @action
  updateTags(tags) {
    this.filteredTags = tags;
  }

  @action
  updateExcludedTags(tags) {
    this.excludedTags = tags;
  }

  @action
  async saveFilters() {
    try {
      const filterParts = [];

      // Sort orders
      if (this.sortOrders.length > 0) {
        const orderValues = this.sortOrders.map((order) =>
          order.direction === "asc" ? `${order.key}-asc` : order.key
        );
        filterParts.push(`order:${orderValues.join(",")}`);
      }

      // Categories
      if (this.filteredCategories.length > 0) {
        filterParts.push(
          `category:${this.filteredCategories.map((c) => c.slug).join(",")}`
        );
      }
      if (this.excludedCategories.length > 0) {
        filterParts.push(
          `-category:${this.excludedCategories.map((c) => c.slug).join(",")}`
        );
      }

      // Tags
      if (this.filteredTags.length > 0) {
        filterParts.push(`tag:${this.filteredTags.join(",")}`);
      }
      if (this.excludedTags.length > 0) {
        filterParts.push(`-tag:${this.excludedTags.join(",")}`);
      }

      // Status filters
      if (this.statusFilters.length > 0) {
        this.statusFilters.forEach((status) => {
          filterParts.push(`status:${status}`);
        });
      }

      // Activity filters
      if (this.activityFilters.before) {
        filterParts.push(`activity-before:${this.activityFilters.before}`);
      }
      if (this.activityFilters.after) {
        filterParts.push(`activity-after:${this.activityFilters.after}`);
      }

      // Created filters
      if (this.createdFilters.before) {
        filterParts.push(`created-before:${this.createdFilters.before}`);
      }
      if (this.createdFilters.after) {
        filterParts.push(`created-after:${this.createdFilters.after}`);
      }
      // Post count filters
      if (this.postCountFilters.min) {
        filterParts.push(`posts-min:${this.postCountFilters.min}`);
      }
      if (this.postCountFilters.max) {
        filterParts.push(`posts-max:${this.postCountFilters.max}`);
      }

      // View count filters
      if (this.viewCountFilters.min) {
        filterParts.push(`views-min:${this.viewCountFilters.min}`);
      }
      if (this.viewCountFilters.max) {
        filterParts.push(`views-max:${this.viewCountFilters.max}`);
      }

      // Like count filters
      if (this.likeCountFilters.min) {
        filterParts.push(`likes-min:${this.likeCountFilters.min}`);
      }
      if (this.likeCountFilters.max) {
        filterParts.push(`likes-max:${this.likeCountFilters.max}`);
      }

      // Poster count filters
      if (this.posterCountFilters.min) {
        filterParts.push(`posters-min:${this.posterCountFilters.min}`);
      }
      if (this.posterCountFilters.max) {
        filterParts.push(`posters-max:${this.posterCountFilters.max}`);
      }

      const filterString = filterParts.join(" ");

      // Navigate to the filtered view
      this.router.transitionTo("discovery.filter", {
        queryParams: { q: filterString },
      });

      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      @title={{I18n.t "topic.filters.edit_filters"}}
      @closeModal={{@closeModal}}
      class="edit-discovery-filters"
    >
      <:body>
        {{! Sort Order Section }}
        <div class="edit-discovery-filters__section">
          <h3>{{I18n.t "topic.filters.sort_by_title"}}</h3>
          {{#each this.sortOrders as |order index|}}
            <div class="edit-discovery-filters__sort-order">
              <ComboBox
                @value={{order.key}}
                @content={{this.availableSortOrders}}
                @onChange={{fn this.updateSortOrder index "key"}}
                @options={{hash clearable=false}}
              />
              <ComboBox
                @value={{order.direction}}
                @content={{array
                  (hash id="desc" name=(I18n.t "topic.filters.sort_descending"))
                  (hash id="asc" name=(I18n.t "topic.filters.sort_ascending"))
                }}
                @onChange={{fn this.updateSortOrder index "direction"}}
                @options={{hash clearable=false}}
              />
              <DButton
                @icon="times"
                @action={{fn this.removeSortOrder index}}
                @title={{I18n.t "topic.filters.remove"}}
                class="btn-flat btn-icon"
              />
            </div>
          {{/each}}
          {{#if (lt this.sortOrders.length 3)}}
            <DButton
              @label="topic.filters.add_sort_order"
              @icon="plus"
              @action={{this.addSortOrder}}
              class="btn-flat add-sort-order"
            />
          {{/if}}
        </div>

        {{! Status Filters }}
        <div class="edit-discovery-filters__section">
          <h3>{{I18n.t "topic.filters.status.title"}}</h3>
          <div class="edit-discovery-filters__status-filters">
            {{#each this.availableStatusFilters as |status|}}
              <label class="checkbox-label">
                <input
                  type="checkbox"
                  checked={{includes this.statusFilters status.id}}
                  {{on "change" (fn this.toggleStatusFilter status.id)}}
                />
                {{status.name}}
              </label>
            {{/each}}
          </div>
        </div>

        {{! Category Filters }}
        <div class="edit-discovery-filters__section">
          <h3>{{I18n.t "topic.filters.categories"}}</h3>
          <div class="edit-discovery-filters__row">
            <label>{{I18n.t "topic.filters.include"}}</label>
            <CategoryChooser
              @value={{this.filteredCategories}}
              @onChange={{this.updateCategories}}
              @options={{hash
                allowUncategorized=true
                clearable=true
                maximum=10
              }}
            />
          </div>
          <div class="edit-discovery-filters__row">
            <label>{{I18n.t "topic.filters.exclude"}}</label>
            <CategoryChooser
              @value={{this.excludedCategories}}
              @onChange={{this.updateExcludedCategories}}
              @options={{hash
                allowUncategorized=true
                clearable=true
                maximum=10
              }}
            />
          </div>
        </div>

        {{! Tag Filters }}
        {{#if this.site.can_tag_topics}}
          <div class="edit-discovery-filters__section">
            <h3>{{I18n.t "topic.filters.tags"}}</h3>
            <div class="edit-discovery-filters__row">
              <label>{{I18n.t "topic.filters.include"}}</label>
              <TagChooser
                @tags={{this.filteredTags}}
                @onChange={{this.updateTags}}
                @everyTag={{true}}
                @allowCreate={{false}}
                @maximum={{10}}
              />
            </div>
            <div class="edit-discovery-filters__row">
              <label>{{I18n.t "topic.filters.exclude"}}</label>
              <TagChooser
                @tags={{this.excludedTags}}
                @onChange={{this.updateExcludedTags}}
                @everyTag={{true}}
                @allowCreate={{false}}
                @maximum={{10}}
              />
            </div>
          </div>
        {{/if}}

        {{! Date Filters }}
        <div class="edit-discovery-filters__section">
          <h3>{{I18n.t "topic.filters.activity_date"}}</h3>
          <div class="edit-discovery-filters__date-row">
            <label>{{I18n.t "topic.filters.after"}}</label>
            <TextField
              @value={{this.activityFilters.after}}
              @placeholder={{I18n.t "topic.filters.date_placeholder"}}
              @onChange={{fn (mut this.activityFilters.after)}}
            />
            <label>{{I18n.t "topic.filters.before"}}</label>
            <TextField
              @value={{this.activityFilters.before}}
              @placeholder={{I18n.t "topic.filters.date_placeholder"}}
              @onChange={{fn (mut this.activityFilters.before)}}
            />
          </div>
        </div>

        <div class="edit-discovery-filters__section">
          <h3>{{I18n.t "topic.filters.created_date"}}</h3>
          <div class="edit-discovery-filters__date-row">
            <label>{{I18n.t "topic.filters.after"}}</label>
            <TextField
              @value={{this.createdFilters.after}}
              @placeholder={{I18n.t "topic.filters.date_placeholder"}}
              @onChange={{fn (mut this.createdFilters.after)}}
            />
            <label>{{I18n.t "topic.filters.before"}}</label>
            <TextField
              @value={{this.createdFilters.before}}
              @placeholder={{I18n.t "topic.filters.date_placeholder"}}
              @onChange={{fn (mut this.createdFilters.before)}}
            />
          </div>
        </div>

        {{! Numeric Filters }}
        <div class="edit-discovery-filters__section">
          <h3>{{I18n.t "topic.filters.post_count"}}</h3>
          <div class="edit-discovery-filters__numeric-row">
            <label>{{I18n.t "topic.filters.minimum"}}</label>
            <TextField
              @value={{this.postCountFilters.min}}
              @type="number"
              @min="0"
              @onChange={{fn (mut this.postCountFilters.min)}}
            />
            <label>{{I18n.t "topic.filters.maximum"}}</label>
            <TextField
              @value={{this.postCountFilters.max}}
              @type="number"
              @min="0"
              @onChange={{fn (mut this.postCountFilters.max)}}
            />
          </div>
        </div>

        <div class="edit-discovery-filters__section">
          <h3>{{I18n.t "topic.filters.view_count"}}</h3>
          <div class="edit-discovery-filters__numeric-row">
            <label>{{I18n.t "topic.filters.minimum"}}</label>
            <TextField
              @value={{this.viewCountFilters.min}}
              @type="number"
              @min="0"
              @onChange={{fn (mut this.viewCountFilters.min)}}
            />
            <label>{{I18n.t "topic.filters.maximum"}}</label>
            <TextField
              @value={{this.viewCountFilters.max}}
              @type="number"
              @min="0"
              @onChange={{fn (mut this.viewCountFilters.max)}}
            />
          </div>
        </div>

        <div class="edit-discovery-filters__section">
          <h3>{{I18n.t "topic.filters.like_count"}}</h3>
          <div class="edit-discovery-filters__numeric-row">
            <label>{{I18n.t "topic.filters.minimum"}}</label>
            <TextField
              @value={{this.likeCountFilters.min}}
              @type="number"
              @min="0"
              @onChange={{fn (mut this.likeCountFilters.min)}}
            />
            <label>{{I18n.t "topic.filters.maximum"}}</label>
            <TextField
              @value={{this.likeCountFilters.max}}
              @type="number"
              @min="0"
              @onChange={{fn (mut this.likeCountFilters.max)}}
            />
          </div>
        </div>

        <div class="edit-discovery-filters__section">
          <h3>{{I18n.t "topic.filters.poster_count"}}</h3>
          <div class="edit-discovery-filters__numeric-row">
            <label>{{I18n.t "topic.filters.minimum"}}</label>
            <TextField
              @value={{this.posterCountFilters.min}}
              @type="number"
              @min="0"
              @onChange={{fn (mut this.posterCountFilters.min)}}
            />
            <label>{{I18n.t "topic.filters.maximum"}}</label>
            <TextField
              @value={{this.posterCountFilters.max}}
              @type="number"
              @min="0"
              @onChange={{fn (mut this.posterCountFilters.max)}}
            />
          </div>
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{this.saveFilters}}
          @label="topic.filters.apply_filters"
          @class="btn-primary"
        />
        <DButton @action={{@closeModal}} @label="cancel" @class="btn-flat" />
      </:footer>
    </DModal>
  </template>
}
