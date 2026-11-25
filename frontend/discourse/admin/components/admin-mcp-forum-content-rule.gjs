import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import Form from "discourse/components/form";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

/**
 * Configures the "Topics and posts" rule, which limits the topics and posts
 * that agents can reach through the MCP server by category and tag.
 *
 * Categories cover their whole subtree. The deny lists always win over the
 * allow lists.
 */
export default class AdminMcpForumContentRule extends Component {
  /**
   * The initial form values, built from the stored config. Tags are edited by
   * name, and categories as category records.
   *
   * @returns {Object}
   */
  @cached
  get formData() {
    const config = this.args.ruleKind.config ?? {};

    return {
      allow_mode: config.allow?.mode ?? "all",
      allow_categories: this.#categories(config.allow?.category_ids),
      allow_tags: this.#tagNames(config.allow?.tag_ids),
      deny_categories: this.#categories(config.deny?.category_ids),
      deny_tags: this.#tagNames(config.deny?.tag_ids),
    };
  }

  /**
   * The ids the stored rule lists that no longer exist. Such a target covers
   * nothing, so the admin is told to review the rule.
   *
   * @returns {boolean}
   */
  get hasMissingTargets() {
    const references = this.args.ruleKind.references;
    return (
      references?.missing_category_ids?.length > 0 ||
      references?.missing_tag_ids?.length > 0
    );
  }

  /**
   * Lists the subcategories that the selected categories also cover, because
   * a rule on a category applies to its whole subtree.
   *
   * @param {Category[]} categories - The selected categories.
   * @returns {string|undefined} The description, or nothing when no
   *   subcategory is covered.
   */
  coveredSubcategoriesDescription(categories) {
    const names = [
      ...new Set(
        (categories ?? [])
          .flatMap((category) => category.descendants.slice(1))
          .map((category) => category.displayName)
      ),
    ];
    if (names.length === 0) {
      return;
    }

    return i18n(
      "admin.config.mcp.content_restrictions.forum_content.covered_subcategories",
      { categories: names.join(", ") }
    );
  }

  @action
  save(data) {
    return this.args.onSave({
      allow: {
        mode: data.allow_mode,
        category_ids:
          data.allow_mode === "selected"
            ? (data.allow_categories ?? []).map((category) => category.id)
            : [],
        tag_names:
          data.allow_mode === "selected" ? (data.allow_tags ?? []) : [],
      },
      deny: {
        category_ids: (data.deny_categories ?? []).map(
          (category) => category.id
        ),
        tag_names: data.deny_tags ?? [],
      },
    });
  }

  #categories(ids) {
    return Category.findByIds(ids ?? []);
  }

  #tagNames(ids) {
    const listed = new Set(ids ?? []);
    return (this.args.ruleKind.references?.tags ?? [])
      .filter((tag) => listed.has(tag.id))
      .map((tag) => tag.name);
  }

  <template>
    <AdminConfigAreaCard
      class="admin-mcp-content-restrictions__rule --forum-content"
      @description="admin.config.mcp.content_restrictions.forum_content.description"
      @heading="admin.config.mcp.content_restrictions.forum_content.title"
    >
      <:content>
        {{#if this.hasMissingTargets}}
          <p class="admin-mcp-content-restrictions__warning">
            {{i18n
              "admin.config.mcp.content_restrictions.forum_content.missing_targets"
            }}
          </p>
        {{/if}}

        <Form @data={{this.formData}} @onSubmit={{this.save}} as |form data|>
          <form.Field
            @format="large"
            @name="allow_mode"
            @title={{i18n
              "admin.config.mcp.content_restrictions.forum_content.allow"
            }}
            @type="radio-group"
            as |field|
          >
            <field.Control as |radioGroup|>
              <radioGroup.Radio @value="all">
                {{i18n
                  "admin.config.mcp.content_restrictions.forum_content.allow_all"
                }}
              </radioGroup.Radio>
              <radioGroup.Radio @value="selected">
                {{i18n
                  "admin.config.mcp.content_restrictions.forum_content.allow_selected"
                }}
              </radioGroup.Radio>
            </field.Control>
          </form.Field>

          {{#if (eq data.allow_mode "selected")}}
            <form.Field
              @description={{this.coveredSubcategoriesDescription
                data.allow_categories
              }}
              @format="large"
              @name="allow_categories"
              @title={{i18n
                "admin.config.mcp.content_restrictions.forum_content.allow_categories"
              }}
              @type="custom"
              as |field|
            >
              <field.Control>
                <CategorySelector
                  @categories={{field.value}}
                  @onChange={{field.set}}
                />
              </field.Control>
            </form.Field>

            <form.Field
              @format="large"
              @name="allow_tags"
              @title={{i18n
                "admin.config.mcp.content_restrictions.forum_content.allow_tags"
              }}
              @type="tag-chooser"
              as |field|
            >
              <field.Control @excludeSynonyms={{true}} @showAllTags={{true}} />
            </form.Field>
          {{/if}}

          <form.Field
            @description={{this.coveredSubcategoriesDescription
              data.deny_categories
            }}
            @format="large"
            @name="deny_categories"
            @title={{i18n
              "admin.config.mcp.content_restrictions.forum_content.deny_categories"
            }}
            @type="custom"
            as |field|
          >
            <field.Control>
              <CategorySelector
                @categories={{field.value}}
                @onChange={{field.set}}
              />
            </field.Control>
          </form.Field>

          <form.Field
            @description={{i18n
              "admin.config.mcp.content_restrictions.forum_content.deny_description"
            }}
            @format="large"
            @name="deny_tags"
            @title={{i18n
              "admin.config.mcp.content_restrictions.forum_content.deny_tags"
            }}
            @type="tag-chooser"
            as |field|
          >
            <field.Control @excludeSynonyms={{true}} @showAllTags={{true}} />
          </form.Field>

          <form.Actions>
            <form.Submit
              class="admin-mcp-content-restrictions__save"
              @label={{if
                @ruleKind.active
                "admin.config.mcp.content_restrictions.forum_content.save"
                "admin.config.mcp.content_restrictions.forum_content.turn_on"
              }}
            />
            {{#if @ruleKind.active}}
              <DButton
                class="btn-default admin-mcp-content-restrictions__turn-off"
                @action={{@onDelete}}
                @label="admin.config.mcp.content_restrictions.forum_content.turn_off"
              />
            {{/if}}
          </form.Actions>
        </Form>
      </:content>
    </AdminConfigAreaCard>
  </template>
}
