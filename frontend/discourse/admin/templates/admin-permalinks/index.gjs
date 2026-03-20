import { fn } from "@ember/helper";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DTextField from "discourse/ui-kit/d-text-field";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.hasPermalinks}}
    <div class="d-admin-filter">
      <div class="admin-filter__input-container permalink-search">
        <DTextField
          @value={{@controller.filter}}
          @placeholderKey="admin.permalink.form.filter"
          @autocorrect="off"
          @autocapitalize="off"
          class="admin-filter__input"
        />
      </div>
    </div>
  {{/if}}

  <DConditionalLoadingSpinner @condition={{@controller.loading}}>
    <div class="permalink-results">
      {{#if @controller.model.length}}
        <table class="d-table permalinks">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell">{{i18n
                  "admin.permalink.url"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "admin.permalink.destination"
                }}</th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each @controller.model as |pl|}}
              <tr
                class={{dConcatClass
                  "d-table__row admin-permalink-item"
                  pl.key
                }}
              >
                <td class="d-table__cell --overview">
                  <DButton
                    @title="admin.permalink.copy_to_clipboard"
                    @icon="far-clipboard"
                    @action={{fn @controller.copyUrl pl}}
                    class="btn-flat"
                  />
                  <span
                    id="admin-permalink-{{pl.id}}"
                    class="admin-permalink-item__url"
                    title={{pl.url}}
                  >{{pl.url}}</span>
                </td>
                <td class="d-table__cell --detail destination">
                  {{#if pl.topic_id}}
                    <a href={{pl.topic_url}}>{{pl.topic_title}}</a>
                  {{/if}}
                  {{#if pl.post_id}}
                    <a href={{pl.post_url}}>{{pl.post_topic_title}}
                      #{{pl.post_number}}</a>
                  {{/if}}
                  {{#if pl.category_id}}
                    {{dCategoryLink pl.category}}
                  {{/if}}
                  {{#if pl.tag_id}}
                    <a href={{pl.tag_url}}>{{pl.tag_name}}</a>
                  {{/if}}
                  {{#if pl.external_url}}
                    {{#if pl.linkIsExternal}}
                      {{dIcon "up-right-from-square"}}
                    {{/if}}
                    <a href={{pl.external_url}}>{{pl.external_url}}</a>
                  {{/if}}
                  {{#if pl.user_id}}
                    <a href={{pl.user_url}}>{{pl.username}}</a>
                  {{/if}}
                </td>
                <td class="d-table__cell --controls">
                  <div class="d-table__cell-actions">
                    <DButton
                      class="btn-default btn-small admin-permalink-item__edit"
                      @route="adminPermalinks.edit"
                      @routeModels={{pl}}
                      @label="admin.config_areas.permalinks.edit"
                    />

                    <DMenu
                      @identifier="permalink-menu"
                      @title={{i18n "admin.permalink.more_options"}}
                      @icon="ellipsis-vertical"
                      @onRegisterApi={{@controller.onRegisterApi}}
                    >
                      <:content>
                        <DDropdownMenu as |dropdown|>
                          <dropdown.item>
                            <DButton
                              @action={{fn @controller.destroyRecord pl}}
                              @icon="trash-can"
                              class="btn-transparent --danger admin-permalink-item__delete"
                              @label="admin.config_areas.permalinks.delete"
                            />
                          </dropdown.item>
                        </DDropdownMenu>
                      </:content>
                    </DMenu>
                  </div>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        {{#if @controller.filter}}
          <p class="permalink-results__no-result">{{i18n
              "search.no_results"
            }}</p>
        {{else}}
          <AdminConfigAreaEmptyList
            @ctaLabel="admin.permalink.add"
            @ctaRoute="adminPermalinks.new"
            @ctaClass="admin-permalinks__add-permalink"
            @emptyLabel="admin.permalink.no_permalinks"
          />
        {{/if}}
      {{/if}}
    </div>
  </DConditionalLoadingSpinner>
</template>
