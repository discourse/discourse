import Component from "@glimmer/component";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageHeader from "discourse/components/d-page-header";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";
import ColorSchemeSelectBaseModal from "admin/components/modal/color-scheme-select-base";

export default class AdminConfigAreasColorPalettes extends Component {
  @service router;
  @service modal;

  get baseColorPalettes() {
    return this.args.palettes.filter((palette) => palette.is_base);
  }

  @action
  newColorPalette() {
    this.modal.show(ColorSchemeSelectBaseModal, {
      model: {
        baseColorSchemes: this.baseColorPalettes,
        newColorSchemeWithBase: this.newColorPaletteWithBase,
      },
    });
  }

  @action
  async newColorPaletteWithBase(baseKey) {
    const base = this.baseColorPalettes.find(
      (palette) => palette.base_scheme_id === baseKey
    );
    const newPalette = base.copy();
    newPalette.setProperties({
      name: i18n("admin.customize.colors.new_name"),
      base_scheme_id: base.get("base_scheme_id"),
    });
    await newPalette.save();
    await this.router.refresh();
    this.router.replaceWith("adminConfig.colorPalettes.show", newPalette);
  }

  <template>
    <DPageHeader
      @titleLabel={{i18n "admin.config.color_palettes.title"}}
      @descriptionLabel={{i18n
        "admin.config.color_palettes.header_description"
      }}
      @learnMoreUrl="https://meta.discourse.org/t/allow-users-to-select-new-color-palettes/60857"
      @hideTabs={{true}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/config/colors"
          @label={{i18n "admin.config.color_palettes.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-config-area">
      <div class="admin-config-area__aside color-palettes-list">
        <PluginOutlet @name="admin-customize-colors-new-button">
          <DButton
            @action={{this.newColorPalette}}
            @icon="plus"
            @label="admin.customize.new"
            class="btn-default create-new-palette"
          />
        </PluginOutlet>
        <ul>
          {{#each @palettes as |palette|}}
            {{#unless palette.is_base}}
              <li data-palette-id={{palette.id}}>
                <LinkTo
                  @route="adminConfig.colorPalettes.show"
                  @model={{palette}}
                  @replace={{true}}
                >
                  {{palette.description}}
                </LinkTo>
              </li>
            {{/unless}}
          {{/each}}
        </ul>
      </div>

      <div class="admin-config-area__primary-content">
        {{outlet}}
      </div>
    </div>
  </template>
}
