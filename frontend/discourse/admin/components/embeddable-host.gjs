import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import { i18n } from "discourse-i18n";

export default class EmbeddableHost extends Component {
  @service dialog;

  @tracked category = null;
  @tracked tags = null;
  @tracked user = null;

  constructor() {
    super(...arguments);

    this.host = this.args.host;
    const categoryId =
      this.host.category_id || this.site.uncategorized_category_id;
    const category = Category.findById(categoryId);

    this.category = category;
    this.tags = (this.host.tags || []).map((t) => t.name).join(", ");
    this.user = this.host.user;
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: i18n("admin.embedding.confirm_delete"),
      didConfirm: () => {
        return this.host.destroyRecord().then(() => {
          this.args.deleteHost(this.host);
        });
      },
    });
  }

  <template>
    <tr class="d-table__row">
      <td class="d-table__cell --overview">
        {{this.host.host}}
      </td>
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">
          {{i18n "admin.embedding.allowed_paths"}}
        </div>
        {{this.host.allowed_paths}}
      </td>
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">
          {{i18n "admin.embedding.category"}}
        </div>
        {{dCategoryBadge this.category allowUncategorized=true}}
      </td>
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">
          {{i18n "admin.embedding.tags"}}
        </div>
        {{this.tags}}
      </td>
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">
          {{#if @controller.embedding.embed_by_username}}
            {{i18n
              "admin.embedding.post_author_with_default"
              author=@controller.embedding.embed_by_username
            }}
          {{else}}
            {{i18n "admin.embedding.post_author"}}
          {{/if}}
        </div>
        {{this.user}}
      </td>

      <td class="d-table__cell --controls">
        <div class="d-table__cell-actions">
          <DButton
            class="btn-default btn-small admin-embeddable-host-item__edit"
            @label="admin.embedding.edit"
            @route="adminEmbedding.edit"
            @routeModels={{this.host}}
          />
          <DMenu
            @icon="ellipsis-vertical"
            @identifier="embedding-host-menu"
            @onRegisterApi={{this.onRegisterApi}}
            @title={{i18n "admin.embedding.more_options.title"}}
          >
            <:content>
              <DDropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    class="btn-transparent --danger admin-embeddable-host-item__delete"
                    @action={{this.delete}}
                    @icon="trash-can"
                    @label="admin.embedding.delete"
                  />
                </dropdown.item>
              </DDropdownMenu>
            </:content>
          </DMenu>
        </div>
      </td>
    </tr>
  </template>
}
