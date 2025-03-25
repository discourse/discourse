import RouteTemplate from 'ember-route-template'
import DPageHeader from "discourse/components/d-page-header";
import i18n from "discourse/helpers/i18n";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse/helpers/d-icon";
import PluginOutlet from "discourse/components/plugin-outlet";
import DButton from "discourse/components/d-button";
export default RouteTemplate(<template><DPageHeader @titleLabel={{i18n "admin.config.color_palettes.title"}} @descriptionLabel={{i18n "admin.config.color_palettes.header_description"}} @learnMoreUrl="https://meta.discourse.org/t/allow-users-to-select-new-color-palettes/60857" @hideTabs={{true}}>
  <:breadcrumbs>
    <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
    <DBreadcrumbsItem @path="/admin/customize/colors" @label={{i18n "admin.config.color_palettes.title"}} />
  </:breadcrumbs>
</DPageHeader>

<div class="content-list color-schemes">
  <ul>
    {{#each @controller.model as |scheme|}}
      {{#unless scheme.is_base}}
        <li>
          <LinkTo @route="adminCustomize.colors.show" @model={{scheme}} @replace={{true}}>
            {{dIcon "paintbrush"}}
            {{scheme.description}}
          </LinkTo>
        </li>
      {{/unless}}
    {{/each}}
  </ul>

  <PluginOutlet @name="admin-customize-colors-new-button">
    <DButton @action={{@controller.newColorScheme}} @icon="plus" @label="admin.customize.new" class="btn-default" />
  </PluginOutlet>
</div>

{{outlet}}

<div class="clearfix"></div></template>)