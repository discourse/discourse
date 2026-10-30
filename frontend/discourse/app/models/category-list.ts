import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { number } from "discourse/lib/formatter";
import LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";
import PreloadStore from "discourse/lib/preload-store";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { applyValueTransformer } from "discourse/lib/transformer";
import type {
  CategoryFields,
  default as Category,
} from "discourse/models/category";
import Site from "discourse/models/site";
import Topic, { type TopicCreateAttrs } from "discourse/models/topic";
import type { TopicListParams } from "discourse/models/topic-list";
import type StoreService from "discourse/services/store";
import { i18n } from "discourse-i18n";

/** Detailed categories contain listable topic payloads and recursively serialized children. */
export interface CategoryListCategory extends Omit<
  CategoryFields,
  "topics" | "subcategory_list"
> {
  topics?: (TopicCreateAttrs<Topic> | Topic)[];
  subcategory_list?: CategoryListCategory[];
}

export interface CategoryListEnvelope {
  category_list?: {
    categories?: CategoryListCategory[];
    can_create_category?: boolean;
    can_create_topic?: boolean;
  };
}

/** Only the combined categories page installs loadBefore; it does not initialize params. */
export interface CategoryListFields {
  params?: TopicListParams;
  loadBefore?: (topicIds: number[], storeInSession?: boolean) => Promise<void>;
}

export type CategoryListCreateAttrs<M = CategoryList> = Partial<
  Omit<M, "parentCategory">
> & {
  categories?: Category[];
  parentCategory?: Pick<Category, "id"> | null;
} & Record<string, unknown>;

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface CategoryList extends CategoryListFields {}

const STAT_PERIODS = ["week", "month"];

/**
 * Represents a list of categories with their related metadata and functionality
 */
// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class CategoryList extends LegacyArrayLikeObject<Category> {
  /**
   * Creates category objects from API result data
   *
   * @param store - The store instance
   * @param result - The API result containing category data
   * @param parentCategory - Optional parent category
   */
  static categoriesFrom(
    store: StoreService,
    result: CategoryListEnvelope | null | undefined,
    parentCategory: Pick<Category, "id"> | null = null
  ) {
    // Find the period that is most relevant
    const list = result?.category_list?.categories || [];
    const statPeriod =
      STAT_PERIODS.find(
        (period) =>
          list.filter(
            (c) =>
              (c?.[
                `topics_${period}` as "topics_week" | "topics_month"
              ] as number) > 0
          ).length >=
          list.length * 0.66
      ) || "all";

    // Update global category list to make sure that `findById` works as
    // expected later
    list.forEach((c) => Site.current().updateCategory(c));

    const categories = CategoryList.create({ store });
    list.forEach((c: CategoryListCategory | Category) => {
      c = this._buildCategoryResult(c, statPeriod);
      if (
        (parentCategory && c.parent_category_id === parentCategory.id) ||
        (!parentCategory && !c.parent_category_id)
      ) {
        // The reassigned callback parameter now holds the hydrated Category.
        categories.content.push(c as Category);
      }
    });
    return categories;
  }

  /**
   * Builds a category result object with stats and topic data
   * @param rawCategoryData - The raw category data
   * @param statPeriod - The period to use for stats ('week', 'month', or 'all')
   * @internal
   */
  static _buildCategoryResult(
    rawCategoryData: CategoryListCategory,
    statPeriod: string
  ) {
    if (rawCategoryData.topics?.length) {
      rawCategoryData.topics = rawCategoryData.topics.map((t) =>
        Topic.create(t as TopicCreateAttrs<Topic>)
      );
    }

    const stat =
      rawCategoryData[
        `topics_${statPeriod}` as
          | "topics_week"
          | "topics_month"
          | "topics_all_time"
      ]!;
    const isTimedPeriod = statPeriod === "week" || statPeriod === "month";
    if (isTimedPeriod && stat > 0) {
      const unit = i18n(`categories.topic_stat_unit.${statPeriod}`);

      rawCategoryData.stat = i18n("categories.topic_stat", {
        count: stat, // only used to correctly pluralize the string
        number: `<span class="value">${number(stat)}</span>`,
        unit: `<span class="unit">${unit}</span>`,
      });

      rawCategoryData.statTitle = i18n(
        `categories.topic_stat_sentence_${statPeriod}`,
        {
          count: stat,
        }
      );

      rawCategoryData.pickAll = false;
    } else {
      rawCategoryData.stat = `<span class="value">${number(rawCategoryData.topics_all_time!)}</span>`;
      rawCategoryData.statTitle = i18n("categories.topic_sentence", {
        count: rawCategoryData.topics_all_time!,
      });
      rawCategoryData.pickAll = true;
    }

    if (Site.current().mobileView) {
      rawCategoryData.statTotal = i18n("categories.topic_stat_all_time", {
        count: rawCategoryData.topics_all_time!,
        number: `<span class="value">${number(rawCategoryData.topics_all_time!)}</span>`,
      });
    }

    const record = Site.current().updateCategory(rawCategoryData);
    record.setupGroupsAndPermissions();
    return record;
  }

  /**
   * @deprecated Use list() instead
   */
  static listForParent(
    store: StoreService,
    parentCategory: Pick<Category, "id"> | null
  ) {
    deprecated(
      "The listForParent method of CategoryList is deprecated. Use list instead",
      { id: "discourse.category-list.listForParent" }
    );

    return CategoryList.list(store, parentCategory);
  }

  /**
   * Fetches and creates a list of categories
   *
   * @param store - The store instance
   * @param parentCategory - Optional parent category to filter by
   */
  static async list(
    store: StoreService,
    parentCategory: Pick<Category, "id"> | null = null
  ) {
    // TODO(typescript-pending): remove this payload assertion when PreloadStore and ajax preserve response types.
    const result = (await PreloadStore.getAndRemove(
      "categories_list",
      async () => {
        const data: { parent_category_id?: number } = {};
        if (parentCategory) {
          data.parent_category_id = parentCategory.id;
        }
        return ajax("/categories.json", {
          data: applyValueTransformer("category-list-request", data, {
            parentCategory,
          }),
        });
      }
    )) as CategoryListEnvelope | null | undefined;

    const categoryList = result?.category_list || {};
    return CategoryList.create(
      applyValueTransformer(
        "category-list-attributes",
        {
          store,
          categories: this.categoriesFrom(store, result, parentCategory)
            .content,
          parentCategory,
          can_create_category: categoryList.can_create_category,
          can_create_topic: categoryList.can_create_topic,
        },
        { result, parentCategory }
      )
    );
  }

  /**
   * Creates a new CategoryList instance
   *
   * @param attrs - The attributes to initialize with
   */
  static create<M extends LegacyArrayLikeObject>(
    this: new (...args: never[]) => M,
    attrs?: CategoryListCreateAttrs<M>
  ): M;

  static create(attrs: Partial<CategoryList> & Record<string, unknown> = {}) {
    const { categories, ...properties } = attrs;
    return super.create({ content: categories, ...properties });
  }

  @tracked can_create_category?: boolean;
  @tracked can_create_topic?: boolean;
  @tracked fetchedLastPage = false;
  @tracked isLoading = false;
  @tracked page = 1;
  @tracked parentCategory?: Category | null;
  @autoTrackedArray topics?: Topic[];
  store!: StoreService;

  /**
   * @deprecated use the category list instance instead
   */
  get categories() {
    deprecated(
      "Using `CategoryList.categories` property is deprecated. Use `CategoryList.content` instead",
      { id: "discourse.category-list.categories" }
    );
    return this.content;
  }

  /**
   * Loads more categories from the server
   */
  @bind
  async loadMore() {
    if (this.isLoading || this.fetchedLastPage) {
      return;
    }

    this.isLoading = true;

    try {
      const nextPage = this.page + 1;
      const data = {
        page: nextPage,
        ...(this.parentCategory && {
          parent_category_id: this.parentCategory.id,
        }),
      };

      const result = await ajax<CategoryListEnvelope>("/categories.json", {
        data,
      });

      this.page = nextPage;

      const newItems = CategoryList.categoriesFrom(
        this.store,
        result,
        this.parentCategory
      ).content;

      if (!newItems.length) {
        this.fetchedLastPage = true;
      } else {
        newItems.forEach((c) => this.content.push(c));
      }
    } finally {
      this.isLoading = false;
    }
  }
}
