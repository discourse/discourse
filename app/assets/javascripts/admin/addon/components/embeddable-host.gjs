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
    <tr class="d-admin-row__content">
      <td class="d-admin-row__detail">
        {{this.host.host}}
      </td>
      <td class="d-admin-row__detail">
        {{this.host.allowed_paths}}
      </td>
      <td class="d-admin-row__detail">
        {{categoryBadge this.category allowUncategorized=true}}
      </td>
      <td class="d-admin-row__detail">
        {{this.tags}}
      </td>
      <td class="d-admin-row__detail">
        {{this.user}}
      </td>

      <td class="d-admin-row__controls">
        <div class="d-admin-row__controls-options">
          <DButton
            class="btn-small admin-embeddable-host-item__edit"
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
