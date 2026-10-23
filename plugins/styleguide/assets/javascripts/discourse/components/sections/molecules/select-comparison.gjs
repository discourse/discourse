import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import MiniTagChooserControl from "discourse/select-kit/components/mini-tag-chooser";
import TagChooserControl from "discourse/select-kit/components/tag-chooser";
import TagDrop from "discourse/select-kit/components/tag-drop";
import TagDropdown from "discourse/select-kit/components/tag-dropdown";
import TagGroupChooserControl from "discourse/select-kit/components/tag-group-chooser";
import TagsIntersectionChooser from "discourse/select-kit/components/tags-intersection-chooser";
import DMiniTagChooser from "discourse/ui-kit/select/recipes/tags/d-mini-tag-chooser";
import {
  ALL_TAGS_ID,
  NO_TAG_ID,
} from "discourse/ui-kit/select/recipes/tags/d-select-tag-filter";
import DTagChooser from "discourse/ui-kit/select/recipes/tags/d-tag-chooser";
import DTagDrop from "discourse/ui-kit/select/recipes/tags/d-tag-drop";
import DTagDropdown from "discourse/ui-kit/select/recipes/tags/d-tag-dropdown";
import DTagGroupChooser from "discourse/ui-kit/select/recipes/tags/d-tag-group-chooser";
import DTagsIntersectionChooser from "discourse/ui-kit/select/recipes/tags/d-tags-intersection-chooser";
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
  updateTag(id, tag) {
    this.value =
      id === ALL_TAGS_ID
        ? null
        : id === NO_TAG_ID
          ? { id: NO_TAG_ID, name: "none" }
          : tag;
  }
}

export default class SelectComparison extends Component {
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

  tags = initialTags();

  get legacyMainTag() {
    return this.legacyIntersection.value[0];
  }

  get legacyAdditionalTags() {
    return this.legacyIntersection.value.slice(1);
  }

  get newMainTag() {
    return this.newIntersection.value[0];
  }

  get newAdditionalTags() {
    return this.newIntersection.value.slice(1);
  }

  <template>
    <div class="styleguide-select-comparison">
      <section
        class="styleguide-select-comparison__pair"
        data-pair="tag-chooser"
      >
        <h3>{{i18n "styleguide.sections.select_comparison.tag_chooser"}}</h3>
        <p class="styleguide-select-comparison__description">{{i18n
            "styleguide.sections.select_comparison.tag_chooser_description"
          }}</p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <TagChooser
              @allowCreate={{false}}
              @onChange={{this.legacyTags.update}}
              @options={{hash maximum=5}}
              @tags={{this.legacyTags.value}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyTags.value)
              }}</small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DTagChooser
              @allowCreate={{false}}
              @maximum={{5}}
              @onChange={{this.newTags.update}}
              @tags={{this.newTags.value}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newTags.value)
              }}</small>
          </div>
        </div>
      </section>

      <section
        class="styleguide-select-comparison__pair"
        data-pair="mini-tag-chooser"
      >
        <h3>{{i18n
            "styleguide.sections.select_comparison.mini_tag_chooser"
          }}</h3>
        <p class="styleguide-select-comparison__description">{{i18n
            "styleguide.sections.select_comparison.mini_tag_chooser_description"
          }}</p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <MiniTagChooser
              @onChange={{this.legacyMiniTags.update}}
              @options={{hash allowAny=false maximum=5}}
              @value={{this.legacyMiniTags.value}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyMiniTags.value)
              }}</small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DMiniTagChooser
              @maximum={{5}}
              @onChange={{this.newMiniTags.update}}
              @preventCreate={{true}}
              @value={{this.newMiniTags.value}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newMiniTags.value)
              }}</small>
          </div>
        </div>
      </section>

      <section class="styleguide-select-comparison__pair" data-pair="tag-drop">
        <h3>{{i18n "styleguide.sections.select_comparison.tag_drop"}}</h3>
        <p class="styleguide-select-comparison__description">{{i18n
            "styleguide.sections.select_comparison.tag_drop_description"
          }}</p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <DemoTagDrop
              @onChange={{this.legacyTag.updateTag}}
              @tag={{this.legacyTag.value}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyTag.value)
              }}</small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DTagDrop
              @onChange={{this.newTag.updateTag}}
              @tag={{this.newTag.value}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newTag.value)
              }}</small>
          </div>
        </div>
      </section>

      <section
        class="styleguide-select-comparison__pair"
        data-pair="tags-intersection-chooser"
      >
        <h3>{{i18n
            "styleguide.sections.select_comparison.tags_intersection_chooser"
          }}</h3>
        <p class="styleguide-select-comparison__description">{{i18n
            "styleguide.sections.select_comparison.tags_intersection_chooser_description"
          }}</p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <DemoTagsIntersectionChooser
              @additionalTags={{this.legacyAdditionalTags}}
              @mainTag={{this.legacyMainTag}}
              @onChange={{this.legacyIntersection.update}}
              @options={{hash allowAny=false maximum=5}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyIntersection.value)
              }}</small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DTagsIntersectionChooser
              @additionalTags={{this.newAdditionalTags}}
              @mainTag={{this.newMainTag}}
              @maximum={{5}}
              @onChange={{this.newIntersection.update}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newIntersection.value)
              }}</small>
          </div>
        </div>
      </section>

      <section
        class="styleguide-select-comparison__pair"
        data-pair="tag-dropdown"
      >
        <h3>{{i18n "styleguide.sections.select_comparison.tag_dropdown"}}</h3>
        <p class="styleguide-select-comparison__description">{{i18n
            "styleguide.sections.select_comparison.tag_dropdown_description"
          }}</p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <DemoTagDropdown
              aria-label={{i18n "tagging.settings.select_tag"}}
              @onChange={{this.legacyTagName.update}}
              @tags={{this.tags}}
              @value={{this.legacyTagName.value}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyTagName.value)
              }}</small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DTagDropdown
              @label={{i18n "tagging.settings.select_tag"}}
              @onChange={{this.newTagName.update}}
              @tags={{this.tags}}
              @value={{this.newTagName.value}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newTagName.value)
              }}</small>
          </div>
        </div>
      </section>

      <section
        class="styleguide-select-comparison__pair"
        data-pair="tag-group-chooser"
      >
        <h3>{{i18n
            "styleguide.sections.select_comparison.tag_group_chooser"
          }}</h3>
        <p class="styleguide-select-comparison__description">{{i18n
            "styleguide.sections.select_comparison.tag_group_chooser_description"
          }}</p>
        <div class="styleguide-select-comparison__controls">
          <div class="styleguide-select-comparison__legacy">
            <h4>{{i18n "styleguide.sections.select_comparison.legacy"}}</h4>
            <TagGroupChooser
              @onChange={{this.legacyTagGroups.update}}
              @tagGroups={{this.legacyTagGroups.value}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.legacyTagGroups.value)
              }}</small>
          </div>
          <div class="styleguide-select-comparison__new">
            <h4>{{i18n "styleguide.sections.select_comparison.new"}}</h4>
            <DTagGroupChooser
              @onChange={{this.newTagGroups.update}}
              @tagGroups={{this.newTagGroups.value}}
            />
            <small class="styleguide-select-comparison__value">{{i18n
                "styleguide.sections.select_comparison.current_value"
                value=(formatValue this.newTagGroups.value)
              }}</small>
          </div>
        </div>
      </section>

      <p>{{i18n "styleguide.sections.select_comparison.form_kit_note"}}</p>
    </div>
  </template>
}
