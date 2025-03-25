import { Input } from "@ember/component";
import { array, fn } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import ColorInput from "admin/components/color-input";
import InlineEditCheckbox from "admin/components/inline-edit-checkbox";

export default RouteTemplate(
  <template>
    <div class="color-scheme show-current-style">
      <div class="admin-container">
        <h1>{{#if
            @controller.model.theme_id
          }}{{@controller.model.name}}{{else}}<TextField
              @value={{@controller.model.name}}
              class="style-name"
            />{{/if}}</h1>
        <div class="controls">
          {{#unless @controller.model.theme_id}}
            <DButton
              @action={{@controller.save}}
              @disabled={{@controller.model.disableSave}}
              @label="admin.customize.save"
              class="btn-primary"
            />
          {{/unless}}
          <DButton
            @action={{fn @controller.copy @controller.model}}
            @icon="copy"
            @label="admin.customize.copy"
            class="btn-default"
          />
          <DButton
            @action={{fn @controller.copyToClipboard @controller.model}}
            @icon="far-clipboard"
            @label="admin.customize.copy_to_clipboard"
            class="btn-default copy-to-clipboard"
          />
          <span
            class="saving {{unless @controller.model.savingStatus 'hidden'}}"
          >{{@controller.model.savingStatus}}</span>
          {{#if @controller.model.theme_id}}
            <span class="not-editable">
              {{i18n "admin.customize.theme_owner"}}
              <LinkTo
                @route="adminCustomizeThemes.show"
                @models={{array "themes" @controller.model.theme_id}}
              >{{@controller.model.theme_name}}</LinkTo>
            </span>
          {{else}}
            <DButton
              @action={{@controller.destroy}}
              @icon="trash-can"
              @label="admin.customize.delete"
              class="btn-danger"
            />
          {{/if}}
        </div>

        <div class="admin-controls">
          <div class="pull-left">
            {{#if @controller.model.theme_id}}
              <InlineEditCheckbox
                @action={{@controller.applyUserSelectable}}
                @labelKey="admin.customize.theme.color_scheme_user_selectable"
                @checked={{@controller.model.user_selectable}}
                @modelId={{@controller.model.id}}
              />
            {{else}}
              <label class="checkbox-label">
                <Input
                  @type="checkbox"
                  @checked={{@controller.model.user_selectable}}
                />
                {{i18n "admin.customize.theme.color_scheme_user_selectable"}}
              </label>
            {{/if}}
          </div>

          {{#unless @controller.model.theme_id}}
            <div class="pull-right">
              <label class="checkbox-label">
                <Input
                  @type="checkbox"
                  @checked={{@controller.onlyOverridden}}
                />
                {{i18n "admin.settings.show_overriden"}}
              </label>
            </div>
          {{/unless}}
        </div>

        {{#if @controller.colors.length}}
          <table class="table colors">
            <thead>
              <tr>
                <th></th>
                <th class="hex">{{i18n "admin.customize.color"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each @controller.colors as |c|}}
                <tr
                  class="{{if c.changed 'changed'}}
                    {{if c.valid 'valid' 'invalid'}}"
                >
                  <td class="name" title={{c.name}}>
                    <h3>{{c.translatedName}}</h3>
                    <p class="description">{{c.description}}</p>
                  </td>
                  <td class="hex"><ColorInput
                      @hexValue={{c.hex}}
                      @brightnessValue={{c.brightness}}
                      @valid={{c.valid}}
                    /></td>
                  <td class="actions">
                    {{#unless @controller.model.theme_id}}
                      <DButton
                        @action={{fn @controller.revert c}}
                        @title="admin.customize.colors.revert_title"
                        @label="admin.customize.colors.revert"
                        class={{concatClass
                          "btn-default"
                          "revert"
                          (unless c.savedIsOverriden "invisible")
                        }}
                      />
                      <DButton
                        @action={{fn @controller.undo c}}
                        @title="admin.customize.colors.undo_title"
                        @label="admin.customize.colors.undo"
                        class={{concatClass
                          "btn-default"
                          "undo"
                          (unless c.changed "invisible")
                        }}
                      />
                    {{/unless}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <p>{{i18n "search.no_results"}}</p>
        {{/if}}
      </div>
    </div>
  </template>
);
