import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import categoryBadge from "discourse/helpers/category-badge";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

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
    this.tags = (this.host.tags || []).join(", ");
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
        {{categoryBadge this.category allowUncategorized=true}}
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
            @route="adminEmbedding.edit"
            @routeModels={{this.host}}
            @label="admin.embedding.edit"
          />
          <DMenu
            @identifier="embedding-host-menu"
            @title={{i18n "admin.embedding.more_options.title"}}
            @icon="ellipsis-vertical"
            @onRegisterApi={{this.onRegisterApi}}
          >
            <:content>
              <DropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    @action={{this.delete}}
                    @label="admin.embedding.delete"
                    @icon="trash-can"
                    class="btn-transparent btn-danger admin-embeddable-host-item__delete"
                  />
                </dropdown.item>
              </DropdownMenu>
            </:content>
          </DMenu>
        </div>
      </td>
    </tr>
  </template>
}
