import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Category from "discourse/models/category";
import CategoryChooserControl from "discourse/select-kit/components/category-chooser";
import CategoryDropControl from "discourse/select-kit/components/category-drop";
import CategorySelectorControl from "discourse/select-kit/components/category-selector";
import MiniTagChooserControl from "discourse/select-kit/components/mini-tag-chooser";
import TagChooserControl from "discourse/select-kit/components/tag-chooser";
import TagDrop from "discourse/select-kit/components/tag-drop";
import TagDropdown from "discourse/select-kit/components/tag-dropdown";
import TagGroupChooserControl from "discourse/select-kit/components/tag-group-chooser";
import TagsIntersectionChooser from "discourse/select-kit/components/tags-intersection-chooser";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import DSelectCategoryFilter from "discourse/ui-kit/select/recipes/categories/d-select-category-filter";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import DSelectTagFilter, {
  ALL_TAGS_ID,
  NO_TAG_ID,
} from "discourse/ui-kit/select/recipes/tags/d-select-tag-filter";
import DSelectTagGroup from "discourse/ui-kit/select/recipes/tags/d-select-tag-group";
import { i18n } from "discourse-i18n";

function initialTags() {
  return [
    { id: 1, name: "support", slug: "support" },
    { id: 2, name: "feature", slug: "feature" },
  ];
}

function formatValue(value) {
  return JSON.stringify(value);
}

/** Category records reference the site, so the demos show their ids. */
function formatCategories(value) {
  return formatValue(value.map((category) => category.id));
}

/** The drops emit a record or a shortcut id. */
function formatCategoryFilter(value) {
  return formatValue(value?.id ?? value);
}

/** Keeps intentional legacy renders quiet and lets callbacks replace both routing action paths. */
function comparisonControl(Control) {
  return class extends Control {
    actions = { ...this.actions, onChange: null };
    onChange = null;
    skipLegacyRenderDeprecation = true;
  };
}

const TagChooser = comparisonControl(TagChooserControl);
const MiniTagChooser = comparisonControl(MiniTagChooserControl);
const DemoTagDrop = comparisonControl(TagDrop);
const DemoTagDropdown = comparisonControl(TagDropdown);
const TagGroupChooser = comparisonControl(TagGroupChooserControl);
const DemoTagsIntersectionChooser = comparisonControl(TagsIntersectionChooser);
const CategoryChooser = comparisonControl(CategoryChooserControl);
const CategorySelector = comparisonControl(CategorySelectorControl);
const DemoCategoryDrop = comparisonControl(CategoryDropControl);

class DemoSelection {
  @tracked value;

  constructor(value) {
    this.value = value;
  }

  @action
  update(value) {
    this.value = value;
  }

  @action
  updateFilter(value) {
    this.updateTag(value, value);
  }

  @action
  updateTag(id, tag) {
    if (id === ALL_TAGS_ID) {
      this.value = null;
    } else if (id === NO_TAG_ID) {
      this.value = { id: NO_TAG_ID, name: "none" };
    } else {
      this.value = tag;
    }
  }
}

export default class SelectComparison extends Component {
  @service site;

  legacyTags = new DemoSelection(initialTags());
  newTags = new DemoSelection(initialTags());
  legacyMiniTags = new DemoSelection(initialTags());
  newMiniTags = new DemoSelection(initialTags());
  legacyTag = new DemoSelection(null);
  newTag = new DemoSelection(null);
  legacyIntersection = new DemoSelection(initialTags());
  newIntersection = new DemoSelection(initialTags());
  legacyTagName = new DemoSelection("support");
  newTagName = new DemoSelection("support");
  legacyTagGroups = new DemoSelection(["product"]);
  newTagGroups = new DemoSelection(["product"]);

  legacyCategory = new DemoSelection(null);
  newCategory = new DemoSelection(null);
  legacyCategories = new DemoSelection([]);
  newCategories = new DemoSelection([]);
  legacyCategoryFilter = new DemoSelection(null);
  newCategoryFilter = new DemoSelection(null);

  tags = initialTags();

  get topLevelCategories() {
    return this.site.categories.filter(
      (category) => !category.parent_category_id
    );
  }

  get legacyFilterCategory() {
    return Category.findById(this.legacyCategoryFilter.value);
  }

  get legacyMainTag() {
    return this.legacyIntersection.value[0];
  }

  get legacyAdditionalTags() {
    return this.legacyIntersection.value.slice(1);
  }

  <template>
    <div class="styleguide-select-comparison">
      <section
        class="styleguide-select-comparison__pair"
        data-pair="tag-chooser"
      >
        <h3>{{i18n "styleguide.sections.select_comparison.tag_chooser"}}</h3>
        <p class="styleguide-select-comparison__description">
          {{~i18n
            "styleguide.sections.select_comparison.tag_chooser_description"
          ~}}
        </p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <TagChooser
              @allowCreate={{false}}
              @onChange={{this.legacyTags.update}}
              @options={{hash maximum=5}}
              @tags={{this.legacyTags.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyTags.value)
              ~}}
            </small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DSelectTag
              @allowCreate={{false}}
              @maximum={{5}}
              @onChange={{this.newTags.update}}
              @value={{this.newTags.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newTags.value)
              ~}}
            </small>
          </div>
        </div>
      </section>

      <section
        class="styleguide-select-comparison__pair"
        data-pair="mini-tag-chooser"
      >
        <h3>
          {{~i18n "styleguide.sections.select_comparison.mini_tag_chooser"~}}
        </h3>
        <p class="styleguide-select-comparison__description">
          {{~i18n
            "styleguide.sections.select_comparison.mini_tag_chooser_description"
          ~}}
        </p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <MiniTagChooser
              @onChange={{this.legacyMiniTags.update}}
              @options={{hash allowAny=false maximum=5}}
              @value={{this.legacyMiniTags.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyMiniTags.value)
              ~}}
            </small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            {{! TODO (select-kit-replacement-cleanup): Retain the mini chooser's compatibility class during rollout. }}
            <DSelectTag
              @legacyKind="mini-tag-chooser"
              @maximum={{5}}
              @onChange={{this.newMiniTags.update}}
              @value={{this.newMiniTags.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newMiniTags.value)
              ~}}
            </small>
          </div>
        </div>
      </section>

      <section class="styleguide-select-comparison__pair" data-pair="tag-drop">
        <h3>{{i18n "styleguide.sections.select_comparison.tag_drop"}}</h3>
        <p class="styleguide-select-comparison__description">
          {{~i18n
            "styleguide.sections.select_comparison.tag_drop_description"
          ~}}
        </p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <DemoTagDrop
              @onChange={{this.legacyTag.updateTag}}
              @tag={{this.legacyTag.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyTag.value)
              ~}}
            </small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DSelectTagFilter
              @onChange={{this.newTag.updateFilter}}
              @value={{this.newTag.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newTag.value)
              ~}}
            </small>
          </div>
        </div>
      </section>

      <section
        class="styleguide-select-comparison__pair"
        data-pair="tags-intersection-chooser"
      >
        <h3>
          {{~i18n
            "styleguide.sections.select_comparison.tags_intersection_chooser"
          ~}}
        </h3>
        <p class="styleguide-select-comparison__description">
          {{~i18n
            "styleguide.sections.select_comparison.tags_intersection_chooser_description"
          ~}}
        </p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <DemoTagsIntersectionChooser
              @additionalTags={{this.legacyAdditionalTags}}
              @mainTag={{this.legacyMainTag}}
              @onChange={{this.legacyIntersection.update}}
              @options={{hash allowAny=false maximum=5}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyIntersection.value)
              ~}}
            </small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DSelectTagFilter
              @multiple={{true}}
              @onChange={{this.newIntersection.update}}
              @value={{this.newIntersection.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newIntersection.value)
              ~}}
            </small>
          </div>
        </div>
      </section>

      <section
        class="styleguide-select-comparison__pair"
        data-pair="tag-dropdown"
      >
        <h3>{{i18n "styleguide.sections.select_comparison.tag_dropdown"}}</h3>
        <p class="styleguide-select-comparison__description">
          {{~i18n
            "styleguide.sections.select_comparison.tag_dropdown_description"
          ~}}
        </p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <DemoTagDropdown
              aria-label={{i18n "tagging.settings.select_tag"}}
              @onChange={{this.legacyTagName.update}}
              @tags={{this.tags}}
              @value={{this.legacyTagName.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyTagName.value)
              ~}}
            </small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DSelectTag
              @emit="names"
              @excludeSynonyms={{true}}
              @ignoreRestrictions={{true}}
              @label={{i18n "tagging.settings.select_tag"}}
              {{! TODO (select-kit-replacement-cleanup): Retain the dropdown's compatibility class during rollout. }}
              @legacyKind="tag-dropdown"
              @multiple={{false}}
              @onChange={{this.newTagName.update}}
              @value={{this.newTagName.value}}
              @variant="button"
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newTagName.value)
              ~}}
            </small>
          </div>
        </div>
      </section>

      <section
        class="styleguide-select-comparison__pair"
        data-pair="tag-group-chooser"
      >
        <h3>
          {{~i18n "styleguide.sections.select_comparison.tag_group_chooser"~}}
        </h3>
        <p class="styleguide-select-comparison__description">
          {{~i18n
            "styleguide.sections.select_comparison.tag_group_chooser_description"
          ~}}
        </p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <TagGroupChooser
              @onChange={{this.legacyTagGroups.update}}
              @tagGroups={{this.legacyTagGroups.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyTagGroups.value)
              ~}}
            </small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DSelectTagGroup
              @onChange={{this.newTagGroups.update}}
              @value={{this.newTagGroups.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newTagGroups.value)
              ~}}
            </small>
          </div>
        </div>
      </section>

      <section
        class="styleguide-select-comparison__pair"
        data-pair="category-chooser"
      >
        <h3>
          {{~i18n "styleguide.sections.select_comparison.category_chooser"~}}
        </h3>
        <p class="styleguide-select-comparison__description">
          {{~i18n
            "styleguide.sections.select_comparison.category_chooser_description"
          ~}}
        </p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <CategoryChooser
              @onChange={{this.legacyCategory.update}}
              @value={{this.legacyCategory.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyCategory.value)
              ~}}
            </small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DSelectCategory
              @emit="ids"
              @onChange={{this.newCategory.update}}
              @permission="create"
              @value={{this.newCategory.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newCategory.value)
              ~}}
            </small>
          </div>
        </div>
      </section>

      <section
        class="styleguide-select-comparison__pair"
        data-pair="category-selector"
      >
        <h3>
          {{~i18n "styleguide.sections.select_comparison.category_selector"~}}
        </h3>
        <p class="styleguide-select-comparison__description">
          {{~i18n
            "styleguide.sections.select_comparison.category_selector_description"
          ~}}
        </p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <CategorySelector
              @categories={{this.legacyCategories.value}}
              @onChange={{this.legacyCategories.update}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatCategories this.legacyCategories.value)
              ~}}
            </small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DSelectCategory
              @multiple={{true}}
              @onChange={{this.newCategories.update}}
              @value={{this.newCategories.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatCategories this.newCategories.value)
              ~}}
            </small>
          </div>
        </div>
      </section>

      <section
        class="styleguide-select-comparison__pair"
        data-pair="category-drop"
      >
        <h3>{{i18n "styleguide.sections.select_comparison.category_drop"}}</h3>
        <p class="styleguide-select-comparison__description">
          {{~i18n
            "styleguide.sections.select_comparison.category_drop_description"
          ~}}
        </p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <DemoCategoryDrop
              @categories={{this.topLevelCategories}}
              @category={{this.legacyFilterCategory}}
              @onChange={{this.legacyCategoryFilter.update}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatCategoryFilter this.legacyCategoryFilter.value)
              ~}}
            </small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DSelectCategoryFilter
              @items={{this.topLevelCategories}}
              @onChange={{this.newCategoryFilter.update}}
              @value={{this.newCategoryFilter.value}}
            />
            <small class="styleguide-select-comparison__value">
              {{~i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatCategoryFilter this.newCategoryFilter.value)
              ~}}
            </small>
          </div>
        </div>
      </section>

      <p>{{i18n "styleguide.sections.select_comparison.form_kit_note"}}</p>
    </div>
  </template>
}
