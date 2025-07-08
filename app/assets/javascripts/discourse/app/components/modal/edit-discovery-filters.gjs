import Component from "@glimmer/component";
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

  constructor() {
    super(...arguments);
    this.formData = this.buildFormData();
  }

  buildFormData() {
    const data = {
      sortOrders: [],
      filteredCategories: [],
      filteredTags: [],
      excludedCategories: [],
      excludedTags: [],
      statusOpen: false,
      statusClosed: false,
      statusArchived: false,
      statusListed: false,
      statusUnlisted: false,
      statusPinned: false,
      statusBookmarked: false,
      activityFiltersBefore: null,
      activityFiltersAfter: null,
      createdFiltersBefore: null,
      createdFiltersAfter: null,
      postCountFiltersMin: null,
      postCountFiltersMax: null,
      viewCountFiltersMin: null,
      viewCountFiltersMax: null,
      likeCountFiltersMin: null,
      likeCountFiltersMax: null,
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
          data.sortOrders = value.split(",").map((order) => {
            const isAscending = order.endsWith("-asc");
            const innerKey = isAscending ? order.replace("-asc", "") : order;
            return { key: innerKey, direction: isAscending ? "asc" : "desc" };
          });
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
      { id: "title", name: i18n("topic.filters.sort_by.title") },
      { id: "views", name: i18n("topic.filters.sort_by.views") },
      { id: "read", name: i18n("topic.filters.sort_by.read") },
    ];
  }

  get availableStatusFilters() {
    return [
      { id: "statusOpen", name: i18n("topic.filters.status.open") },
      { id: "statusClosed", name: i18n("topic.filters.status.closed") },
      { id: "statusArchived", name: i18n("topic.filters.status.archived") },
      { id: "statusListed", name: i18n("topic.filters.status.listed") },
      { id: "statusUnlisted", name: i18n("topic.filters.status.unlisted") },
      { id: "statusPinned", name: i18n("topic.filters.status.pinned") },
      { id: "statusBookmarked", name: i18n("topic.filters.status.bookmarked") },
    ];
  }

  get directionOptions() {
    return [
      { id: "desc", name: i18n("topic.filters.sort_descending") },
      { id: "asc", name: i18n("topic.filters.sort_ascending") },
    ];
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
  updateTags(tags, { set }) {
    set("filteredTags", tags);
  }

  @action
  updateExcludedTags(tags, { set }) {
    set("excludedTags", tags);
  }

  @action
  async saveFilters(data) {
    try {
      const filterParts = [];

      if (data.sortOrders?.length > 0) {
        const orderValues = data.sortOrders.map((order) =>
          order.direction === "asc" ? `${order.key}-asc` : order.key
        );
        filterParts.push(`order:${orderValues.join(",")}`);
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
      if (data.statusBookmarked) {
        statusValues.push("bookmarked");
      }

      if (statusValues.length > 0) {
        filterParts.push(`status:${statusValues.join(",")}`);
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

      // Numeric filters
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

          {{! Sort Order Section }}
          <form.Section @title={{I18n.t "topic.filters.sort_by_title"}}>
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
                      @onChange={{field.set}}
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
              {{#each this.availableStatusFilters as |status|}}
                <group.Field
                  @name={{status.id}}
                  @title={{status.name}}
                  as |field|
                >
                  {{this.debug status.id}}
                  <field.Checkbox />
                </group.Field>
              {{/each}}
            </form.CheckboxGroup>
          </form.Section>

          <form.Section @title={{I18n.t "topic.filters.categories"}}>
            <form.Field
              @name="filteredCategories"
              @title={{I18n.t "topic.filters.include"}}
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

          {{! Tag Filters }}
          {{#if this.site.can_tag_topics}}
            <form.Section @title={{I18n.t "topic.filters.tags"}}>
              <form.Field
                @name="filteredTags"
                @title={{I18n.t "topic.filters.include"}}
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

          {{! Date Filters }}
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

          {{! Numeric Filters }}
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

          <form.Actions>
            <form.Submit @label="topic.filters.apply_filters" />
            <DButton @action={{@closeModal}} @label="cancel" class="btn-flat" />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
