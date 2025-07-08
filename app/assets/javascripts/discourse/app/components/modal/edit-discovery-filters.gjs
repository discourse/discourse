import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { lt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import I18n, { i18n } from "discourse-i18n";
import CategorySelector from "select-kit/components/category-selector";
import ComboBox from "select-kit/components/combo-box";
import TagChooser from "select-kit/components/tag-chooser";

export default class EditDiscoveryFilters extends Component {
  @service router;
  @service currentUser;
  @service site;

  @tracked showAdvanced = false;

  constructor() {
    super(...arguments);
    this.formData = this.buildFormData();
    this.showAdvanced = this.hasAdvancedFilters();
  }

  hasAdvancedFilters() {
    const data = this.formData;

    if (data.sortOrders.length > 1) {
      return true;
    }

    if (data.excludedCategories.length > 0 || data.excludedTags.length > 0) {
      return true;
    }

    if (
      data.statusArchived ||
      data.statusListed ||
      data.statusUnlisted ||
      data.statusPinned
    ) {
      return true;
    }

    if (
      data.activityFiltersBefore ||
      data.activityFiltersAfter ||
      data.createdFiltersBefore ||
      data.createdFiltersAfter ||
      data.createdBy ||
      data.postCountFiltersMin ||
      data.postCountFiltersMax ||
      data.viewCountFiltersMin ||
      data.viewCountFiltersMax ||
      data.likeCountFiltersMin ||
      data.likeCountFiltersMax ||
      data.likeOpCountFiltersMin ||
      data.likeOpCountFiltersMax ||
      data.posterCountFiltersMin ||
      data.posterCountFiltersMax
    ) {
      return true;
    }

    return false;
  }

  buildFormData() {
    const data = {
      simpleOrder: "activity",
      filteredCategories: [],
      filteredTags: [],
      statusOpen: true,
      statusClosed: false,
      statusBookmarked: false,

      sortOrders: [],
      excludedCategories: [],
      excludedTags: [],
      statusArchived: false,
      statusListed: false,
      statusUnlisted: false,
      statusPinned: false,
      activityFiltersBefore: null,
      activityFiltersAfter: null,
      createdFiltersBefore: null,
      createdFiltersAfter: null,
      createdBy: null,
      postCountFiltersMin: null,
      postCountFiltersMax: null,
      viewCountFiltersMin: null,
      viewCountFiltersMax: null,
      likeCountFiltersMin: null,
      likeCountFiltersMax: null,
      likeOpCountFiltersMin: null,
      likeOpCountFiltersMax: null,
      posterCountFiltersMin: null,
      posterCountFiltersMax: null,
    };

    this.parseExistingFilters(data);
    return data;
  }

  parseExistingFilters(data) {
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
            data.excludedCategories = categories;
          } else {
            data.filteredCategories = categories;
          }
          break;

        case "tag":
          const tags = value.split(",");
          if (isExclude) {
            data.excludedTags = tags;
          } else {
            data.filteredTags = tags;
          }
          break;

        case "order":
          const orders = value.split(",").map((order) => {
            const isAscending = order.endsWith("-asc");
            const innerKey = isAscending ? order.replace("-asc", "") : order;
            return { key: innerKey, direction: isAscending ? "asc" : "desc" };
          });

          data.sortOrders = orders;

          if (orders.length > 0) {
            data.simpleOrder = orders[0].key;
          }
          break;

        case "status":
          value.split(",").forEach((statusId) => {
            const prop = `status${statusId
              .charAt(0)
              .toUpperCase()}${statusId.slice(1)}`;
            if (prop in data) {
              data[prop] = true;
            }
          });
          break;

        case "in":
          if (value === "bookmarked") {
            data.statusBookmarked = true;
          }
          break;

        case "activity-before":
          data.activityFiltersBefore = value;
          break;
        case "activity-after":
          data.activityFiltersAfter = value;
          break;

        case "created-before":
          data.createdFiltersBefore = value;
          break;
        case "created-after":
          data.createdFiltersAfter = value;
          break;

        case "created-by":
          data.createdBy = value;
          break;

        case "posts-min":
          data.postCountFiltersMin = value;
          break;
        case "posts-max":
          data.postCountFiltersMax = value;
          break;

        case "views-min":
          data.viewCountFiltersMin = value;
          break;
        case "views-max":
          data.viewCountFiltersMax = value;
          break;

        case "likes-min":
          data.likeCountFiltersMin = value;
          break;
        case "likes-max":
          data.likeCountFiltersMax = value;
          break;

        case "likes-op-min":
          data.likeOpCountFiltersMin = value;
          break;
        case "likes-op-max":
          data.likeOpCountFiltersMax = value;
          break;

        case "posters-min":
          data.posterCountFiltersMin = value;
          break;
        case "posters-max":
          data.posterCountFiltersMax = value;
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
      { id: "read", name: i18n("topic.filters.sort_by.read") },
      { id: "title", name: i18n("topic.filters.sort_by.title") },
      { id: "views", name: i18n("topic.filters.sort_by.views") },
    ].sort((a, b) => a.name.localeCompare(b.name));
  }

  get commonStatusFilters() {
    return [
      { id: "statusOpen", name: i18n("topic.filters.status.open") },
      { id: "statusClosed", name: i18n("topic.filters.status.closed") },
      { id: "statusBookmarked", name: i18n("topic.filters.status.bookmarked") },
    ];
  }

  get advancedStatusFilters() {
    return [
      { id: "statusArchived", name: i18n("topic.filters.status.archived") },
      { id: "statusListed", name: i18n("topic.filters.status.listed") },
      { id: "statusUnlisted", name: i18n("topic.filters.status.unlisted") },
      { id: "statusPinned", name: i18n("topic.filters.status.pinned") },
    ];
  }

  get directionOptions() {
    return [
      { id: "desc", name: i18n("topic.filters.sort_descending") },
      { id: "asc", name: i18n("topic.filters.sort_ascending") },
    ];
  }

  @action
  toggleAdvanced() {
    this.showAdvanced = !this.showAdvanced;

    if (this.showAdvanced && this.formData.sortOrders.length === 0) {
      this.formData.sortOrders = [
        {
          key: this.formData.simpleOrder,
          direction: "desc",
        },
      ];
    }
  }

  @action
  updateSimpleOrder(data, { set }, value) {
    set("simpleOrder", value);
    if (this.showAdvanced && data.sortOrders.length > 0) {
      this.updateSortOrder(0, "key", value, data, { set });
    }
  }

  @action
  addSortOrder(data, { set }) {
    const newSortOrder = { key: "activity", direction: "desc" };
    set("sortOrders", [...data.sortOrders, newSortOrder]);
  }

  @action
  removeSortOrder(index, data, { set }) {
    const newOrders = data.sortOrders.filter((_, i) => i !== index);
    set("sortOrders", newOrders);
  }

  @action
  updateSortOrder(index, field, value, data, { set }) {
    const updated = [...data.sortOrders];
    updated[index] = { ...updated[index], [field]: value };
    set("sortOrders", updated);

    if (index === 0 && field === "key") {
      set("simpleOrder", value);
    }
  }

  @action
  updateCategories({ set }, categories) {
    set("filteredCategories", categories);
  }

  @action
  updateExcludedCategories({ set }, categories) {
    set("excludedCategories", categories);
  }

  @action
  updateTags({ set }, tags) {
    set("filteredTags", tags);
  }

  @action
  updateExcludedTags({ set }, tags) {
    set("excludedTags", tags);
  }

  @action
  async saveFilters(data) {
    try {
      const filterParts = [];

      if (this.showAdvanced && data.sortOrders?.length > 0) {
        const orderValues = data.sortOrders.map((order) =>
          order.direction === "asc" ? `${order.key}-asc` : order.key
        );
        filterParts.push(`order:${orderValues.join(",")}`);
      } else if (data.simpleOrder) {
        filterParts.push(`order:${data.simpleOrder}`);
      }

      if (data.filteredCategories?.length > 0) {
        filterParts.push(
          `category:${data.filteredCategories.map((c) => c.slug).join(",")}`
        );
      }
      if (data.excludedCategories?.length > 0) {
        filterParts.push(
          `-category:${data.excludedCategories.map((c) => c.slug).join(",")}`
        );
      }

      if (data.filteredTags?.length > 0) {
        filterParts.push(`tag:${data.filteredTags.join(",")}`);
      }
      if (data.excludedTags?.length > 0) {
        filterParts.push(`-tag:${data.excludedTags.join(",")}`);
      }

      const statusValues = [];
      if (data.statusOpen) {
        statusValues.push("open");
      }
      if (data.statusClosed) {
        statusValues.push("closed");
      }
      if (data.statusArchived) {
        statusValues.push("archived");
      }
      if (data.statusListed) {
        statusValues.push("listed");
      }
      if (data.statusUnlisted) {
        statusValues.push("unlisted");
      }
      if (data.statusPinned) {
        statusValues.push("pinned");
      }

      if (statusValues.length > 0) {
        filterParts.push(`status:${statusValues.join(",")}`);
      }

      if (data.statusBookmarked) {
        filterParts.push("in:bookmarked");
      }

      if (data.createdBy) {
        filterParts.push(`created-by:${data.createdBy}`);
      }

      if (data.activityFiltersBefore) {
        filterParts.push(`activity-before:${data.activityFiltersBefore}`);
      }
      if (data.activityFiltersAfter) {
        filterParts.push(`activity-after:${data.activityFiltersAfter}`);
      }
      if (data.createdFiltersBefore) {
        filterParts.push(`created-before:${data.createdFiltersBefore}`);
      }
      if (data.createdFiltersAfter) {
        filterParts.push(`created-after:${data.createdFiltersAfter}`);
      }

      if (data.postCountFiltersMin) {
        filterParts.push(`posts-min:${data.postCountFiltersMin}`);
      }
      if (data.postCountFiltersMax) {
        filterParts.push(`posts-max:${data.postCountFiltersMax}`);
      }
      if (data.viewCountFiltersMin) {
        filterParts.push(`views-min:${data.viewCountFiltersMin}`);
      }
      if (data.viewCountFiltersMax) {
        filterParts.push(`views-max:${data.viewCountFiltersMax}`);
      }
      if (data.likeCountFiltersMin) {
        filterParts.push(`likes-min:${data.likeCountFiltersMin}`);
      }
      if (data.likeCountFiltersMax) {
        filterParts.push(`likes-max:${data.likeCountFiltersMax}`);
      }
      if (data.likeOpCountFiltersMin) {
        filterParts.push(`likes-op-min:${data.likeOpCountFiltersMin}`);
      }
      if (data.likeOpCountFiltersMax) {
        filterParts.push(`likes-op-max:${data.likeOpCountFiltersMax}`);
      }
      if (data.posterCountFiltersMin) {
        filterParts.push(`posters-min:${data.posterCountFiltersMin}`);
      }
      if (data.posterCountFiltersMax) {
        filterParts.push(`posters-max:${data.posterCountFiltersMax}`);
      }

      const filterString = filterParts.join(" ");

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
        <Form
          @data={{this.formData}}
          @onSubmit={{this.saveFilters}}
          as |form data|
        >

          {{#unless this.showAdvanced}}
            <form.Section @title={{I18n.t "topic.filters.categories"}}>
              <form.Field
                @name="filteredCategories"
                @title={{I18n.t "topic.filters.include_categories"}}
                as |field|
              >
                <CategorySelector
                  @categories={{field.value}}
                  @onChange={{fn this.updateCategories form}}
                  @options={{hash
                    allowUncategorized=true
                    clearable=true
                    maximum=10
                  }}
                />
              </form.Field>
            </form.Section>

            {{#if this.site.can_tag_topics}}
              <form.Section @title={{I18n.t "topic.filters.tags"}}>
                <form.Field
                  @name="filteredTags"
                  @title={{I18n.t "topic.filters.include_tags"}}
                  as |field|
                >
                  <TagChooser
                    @tags={{field.value}}
                    @onChange={{fn this.updateTags form}}
                    @everyTag={{true}}
                    @allowCreate={{false}}
                    @maximum={{10}}
                  />
                </form.Field>
              </form.Section>
            {{/if}}

            <form.Section @title={{I18n.t "topic.filters.status.title"}}>
              <form.CheckboxGroup as |group|>
                {{#each this.commonStatusFilters as |status|}}
                  <group.Field
                    @name={{status.id}}
                    @title={{status.name}}
                    as |field|
                  >
                    <field.Checkbox />
                  </group.Field>
                {{/each}}
              </form.CheckboxGroup>
            </form.Section>

            <form.Section @title={{I18n.t "topic.filters.sort_by_title"}}>
              <form.Field
                @name="simpleOrder"
                @title={{I18n.t "topic.filters.sort_field"}}
                as |field|
              >
                <ComboBox
                  @value={{field.value}}
                  @content={{this.availableSortOrders}}
                  @onChange={{fn this.updateSimpleOrder data form}}
                  @options={{hash clearable=false}}
                />
              </form.Field>
            </form.Section>
          {{/unless}}

          {{#if this.showAdvanced}}
            <form.Section @title={{I18n.t "topic.filters.multi_level_sort"}}>
              <form.Collection @name="sortOrders" as |collection index|>
                <form.Row as |row|>
                  <row.Col @size={{4}}>
                    <collection.Field
                      @name="key"
                      @title="Sort Field"
                      @showTitle={{false}}
                      as |field|
                    >
                      <ComboBox
                        @value={{field.value}}
                        @content={{this.availableSortOrders}}
                        @onChange={{fn
                          this.updateSortOrder
                          index
                          "key"
                          field.value
                          data
                          form
                        }}
                        @options={{hash clearable=false}}
                      />
                    </collection.Field>
                  </row.Col>
                  <row.Col @size={{4}}>
                    <collection.Field
                      @name="direction"
                      @title="Direction"
                      @showTitle={{false}}
                      as |field|
                    >
                      <ComboBox
                        @value={{field.value}}
                        @content={{this.directionOptions}}
                        @onChange={{field.set}}
                        @options={{hash clearable=false}}
                      />
                    </collection.Field>
                  </row.Col>
                  <row.Col @size={{4}}>
                    <DButton
                      @icon="times"
                      @action={{fn this.removeSortOrder index data form}}
                      @title={{I18n.t "topic.filters.remove"}}
                      class="btn-flat btn-icon"
                    />
                  </row.Col>
                </form.Row>
              </form.Collection>

              {{#if (lt data.sortOrders.length 3)}}
                <DButton
                  @label="topic.filters.add_sort_order"
                  @icon="plus"
                  @action={{fn this.addSortOrder data form}}
                  class="btn-flat add-sort-order"
                />
              {{/if}}
            </form.Section>

            <form.Section @title={{I18n.t "topic.filters.status.title"}}>
              <form.CheckboxGroup as |group|>
                {{#each this.commonStatusFilters as |status|}}
                  <group.Field
                    @name={{status.id}}
                    @title={{status.name}}
                    as |field|
                  >
                    <field.Checkbox />
                  </group.Field>
                {{/each}}
                {{#each this.advancedStatusFilters as |status|}}
                  <group.Field
                    @name={{status.id}}
                    @title={{status.name}}
                    as |field|
                  >
                    <field.Checkbox />
                  </group.Field>
                {{/each}}
              </form.CheckboxGroup>
            </form.Section>

            <form.Section @title={{I18n.t "topic.filters.categories"}}>
              <form.Field
                @name="filteredCategories"
                @title={{I18n.t "topic.filters.include_categories"}}
                as |field|
              >
                <CategorySelector
                  @categories={{field.value}}
                  @onChange={{fn this.updateCategories form}}
                  @options={{hash
                    allowUncategorized=true
                    clearable=true
                    maximum=10
                  }}
                />
              </form.Field>
              <form.Field
                @name="excludedCategories"
                @title={{I18n.t "topic.filters.exclude"}}
                as |field|
              >
                <CategorySelector
                  @categories={{field.value}}
                  @onChange={{fn this.updateExcludedCategories form}}
                  @options={{hash
                    allowUncategorized=true
                    clearable=true
                    maximum=10
                  }}
                />
              </form.Field>
            </form.Section>

            {{#if this.site.can_tag_topics}}
              <form.Section @title={{I18n.t "topic.filters.tags"}}>
                <form.Field
                  @name="filteredTags"
                  @title={{I18n.t "topic.filters.include_tags"}}
                  as |field|
                >
                  <TagChooser
                    @tags={{field.value}}
                    @onChange={{fn this.updateTags form}}
                    @everyTag={{true}}
                    @allowCreate={{false}}
                    @maximum={{10}}
                  />
                </form.Field>
                <form.Field
                  @name="excludedTags"
                  @title={{I18n.t "topic.filters.exclude"}}
                  as |field|
                >
                  <TagChooser
                    @tags={{field.value}}
                    @onChange={{fn this.updateExcludedTags form}}
                    @everyTag={{true}}
                    @allowCreate={{false}}
                    @maximum={{10}}
                  />
                </form.Field>
              </form.Section>
            {{/if}}

            <form.Section @title={{I18n.t "topic.filters.created_by"}}>
              <form.Field
                @name="createdBy"
                @title={{I18n.t "topic.filters.author"}}
                as |field|
              >
                <field.Input placeholder={{I18n.t "topic.filters.username"}} />
              </form.Field>
            </form.Section>

            <form.Section @title={{I18n.t "topic.filters.activity_date"}}>
              <form.Row as |row|>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="activityFiltersAfter"
                    @title={{I18n.t "topic.filters.after"}}
                    as |field|
                  >
                    <field.Input
                      @type="date"
                      placeholder={{I18n.t "topic.filters.date_placeholder"}}
                    />
                  </form.Field>
                </row.Col>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="activityFiltersBefore"
                    @title={{I18n.t "topic.filters.before"}}
                    as |field|
                  >
                    <field.Input
                      @type="date"
                      placeholder={{I18n.t "topic.filters.date_placeholder"}}
                    />
                  </form.Field>
                </row.Col>
              </form.Row>
            </form.Section>

            <form.Section @title={{I18n.t "topic.filters.created_date"}}>
              <form.Row as |row|>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="createdFiltersAfter"
                    @title={{I18n.t "topic.filters.after"}}
                    as |field|
                  >
                    <field.Input
                      @type="date"
                      placeholder={{I18n.t "topic.filters.date_placeholder"}}
                    />
                  </form.Field>
                </row.Col>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="createdFiltersBefore"
                    @title={{I18n.t "topic.filters.before"}}
                    as |field|
                  >
                    <field.Input
                      @type="date"
                      placeholder={{I18n.t "topic.filters.date_placeholder"}}
                    />
                  </form.Field>
                </row.Col>
              </form.Row>
            </form.Section>

            <form.Section @title={{I18n.t "topic.filters.post_count"}}>
              <form.Row as |row|>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="postCountFiltersMin"
                    @title={{I18n.t "topic.filters.minimum"}}
                    as |field|
                  >
                    <field.Input @type="number" @min="0" />
                  </form.Field>
                </row.Col>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="postCountFiltersMax"
                    @title={{I18n.t "topic.filters.maximum"}}
                    as |field|
                  >
                    <field.Input @type="number" @min="0" />
                  </form.Field>
                </row.Col>
              </form.Row>
            </form.Section>

            <form.Section @title={{I18n.t "topic.filters.view_count"}}>
              <form.Row as |row|>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="viewCountFiltersMin"
                    @title={{I18n.t "topic.filters.minimum"}}
                    as |field|
                  >
                    <field.Input @type="number" @min="0" />
                  </form.Field>
                </row.Col>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="viewCountFiltersMax"
                    @title={{I18n.t "topic.filters.maximum"}}
                    as |field|
                  >
                    <field.Input @type="number" @min="0" />
                  </form.Field>
                </row.Col>
              </form.Row>
            </form.Section>

            <form.Section @title={{I18n.t "topic.filters.like_count"}}>
              <form.Row as |row|>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="likeCountFiltersMin"
                    @title={{I18n.t "topic.filters.minimum"}}
                    as |field|
                  >
                    <field.Input @type="number" @min="0" />
                  </form.Field>
                </row.Col>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="likeCountFiltersMax"
                    @title={{I18n.t "topic.filters.maximum"}}
                    as |field|
                  >
                    <field.Input @type="number" @min="0" />
                  </form.Field>
                </row.Col>
              </form.Row>
            </form.Section>

            <form.Section @title={{I18n.t "topic.filters.op_like_count"}}>
              <form.Row as |row|>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="likeOpCountFiltersMin"
                    @title={{I18n.t "topic.filters.minimum"}}
                    as |field|
                  >
                    <field.Input @type="number" @min="0" />
                  </form.Field>
                </row.Col>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="likeOpCountFiltersMax"
                    @title={{I18n.t "topic.filters.maximum"}}
                    as |field|
                  >
                    <field.Input @type="number" @min="0" />
                  </form.Field>
                </row.Col>
              </form.Row>
            </form.Section>

            <form.Section @title={{I18n.t "topic.filters.poster_count"}}>
              <form.Row as |row|>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="posterCountFiltersMin"
                    @title={{I18n.t "topic.filters.minimum"}}
                    as |field|
                  >
                    <field.Input @type="number" @min="0" />
                  </form.Field>
                </row.Col>
                <row.Col @size={{6}}>
                  <form.Field
                    @name="posterCountFiltersMax"
                    @title={{I18n.t "topic.filters.maximum"}}
                    as |field|
                  >
                    <field.Input @type="number" @min="0" />
                  </form.Field>
                </row.Col>
              </form.Row>
            </form.Section>
          {{/if}}

          <form.Actions>
            <form.Submit @label="topic.filters.apply_filters" />
            <DButton @action={{@closeModal}} @label="cancel" class="btn-flat" />
            <DButton
              @label={{if
                this.showAdvanced
                "topic.filters.hide_advanced"
                "topic.filters.show_advanced"
              }}
              @icon={{if this.showAdvanced "chevron-up" "chevron-down"}}
              @action={{this.toggleAdvanced}}
              class="btn-flat btn-advanced-toggle"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
