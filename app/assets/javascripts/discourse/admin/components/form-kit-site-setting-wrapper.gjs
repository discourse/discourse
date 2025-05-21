import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import { humanizedSettingName } from "discourse/lib/site-settings-utils";
import GroupList from "admin/components/site-settings/group-list";
import SiteSetting from "admin/models/site-setting";

class PrimaryActions extends Component {
  @service toasts;
  @service router;

  get cannotRevert() {
    return this.args.field.value === this.args.setting.default;
  }

  @action
  async revertToDefault(menu) {
    await menu.close();

    this.args.field.set(this.args.setting.default);
    this.args.save({
      [this.args.setting.setting]: this.args.field.value,
    });
  }

  @action
  settingHistory() {
    this.router.transitionTo("adminLogs.staffActionLogs", {
      queryParams: {
        filters: {
          subject: this.args.setting.setting,
          action_name: "change_site_setting",
        },
        force_refresh: true,
      },
    });
  }

  @action
  async copyStettingAsUrl(menu) {
    await menu.close();

    const url = `${window.location.origin}/admin/site_settings/category/all_results?filter=${this.args.setting.setting}`;
    navigator.clipboard.writeText(url).then(() => {
      this.toasts.success({ data: { message: "Copied to clipboard!" } });
    });
  }

  <template>
    <@actions.Menu
      @identifier={{concat "site-setting-menu-" @setting.setting}}
      @icon="gear"
      @class="btn-flat"
    >
      <:content as |menu|>
        <menu.Dropdown as |dropdown|>
          <dropdown.item>
            <DButton
              @disabled={{this.cannotRevert}}
              @action={{fn this.revertToDefault menu}}
            >
              Reset Setting
            </DButton>
          </dropdown.item>
          <dropdown.item>
            <DButton @action={{fn this.copyStettingAsUrl menu}}>Copy Setting as
              URL</DButton>
          </dropdown.item>
          <dropdown.item>
            <DButton @action={{this.settingHistory}}>Setting History</DButton>
          </dropdown.item>
        </menu.Dropdown>
      </:content>
    </@actions.Menu>
  </template>
}

class SecondaryActions extends Component {
  @action
  async discardChanges() {
    await this.args.field.rollback();
  }

  @action
  save() {
    this.args.save({
      [this.args.setting.setting]: this.args.field.value,
    });
    this.args.field.resetPatches();
  }

  <template>
    <@actions.Button
      @icon="check"
      @disabled={{@field.isPristine}}
      @action={{this.save}}
    />
    <@actions.Button
      @icon="xmark"
      @disabled={{@field.isPristine}}
      @action={{this.discardChanges}}
    />
  </template>
}

export default class FormKitSiteSettingWrapper extends Component {
  get settingTitle() {
    return humanizedSettingName(
      this.args.setting.setting,
      this.args.setting.label
    );
  }

  @cached
  get formData() {
    return {
      [this.args.setting.setting]: this.args.setting.value,
    };
  }

  @action
  async save(data) {
    this.args.setting.buffered.set(
      this.args.setting.setting,
      data[this.args.setting.setting]
    );
    this.args.setting.buffered.applyChanges();

    const params = {};
    params[this.args.setting.setting] = {
      value: data[this.args.setting.setting],
      backfill: false,
    };

    await SiteSetting.bulkUpdate(params);
  }

  <template>
    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class={{if @setting.overridden "--overridden"}}
      as |form|
    >
      <form.Field
        @name={{@setting.setting}}
        @title={{this.settingTitle}}
        @description={{htmlSafe @setting.description}}
      >
        <:body as |field|>
          {{#if (eq @setting.type "string")}}
            <field.Input>
              <:primary-actions as |actions|>
                <PrimaryActions
                  @field={{field}}
                  @actions={{actions}}
                  @setting={{@setting}}
                  @save={{this.save}}
                />
              </:primary-actions>
              <:secondary-actions as |actions|>
                <SecondaryActions
                  @field={{field}}
                  @actions={{actions}}
                  @setting={{@setting}}
                  @save={{this.save}}
                />
              </:secondary-actions>
            </field.Input>
          {{else if (eq @setting.type "upload")}}
            <field.Image @type="site_setting">
              <:primary-actions>
                primary
              </:primary-actions>
            </field.Image>
          {{else if (eq @setting.type "bool")}}
            <field.Checkbox>
              {{htmlSafe @setting.description}}
            </field.Checkbox>
          {{else if (eq @setting.type "enum")}}
            <field.Select as |select|>
              {{#each @setting.valid_values as |item|}}
                <select.Option @value={{item.value}}>
                  {{item.name}}
                </select.Option>
              {{/each}}
            </field.Select>
          {{else if (eq @setting.type "group")}}
            <field.Custom>
              {{log field.set}}
              <GroupList @onChange={{field.set}} @value={{field.value}} />
            </field.Custom>
          {{else}}
            {{@setting.type}}
          {{/if}}
        </:body>
      </form.Field>
    </Form>
  </template>
}
