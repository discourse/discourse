import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import FlatButton from "discourse/components/flat-button";
import TextField from "discourse/components/text-field";
import categoryLink from "discourse/helpers/category-link";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import DMenu from "float-kit/components/d-menu";

export default RouteTemplate(
  <template>
    <ConditionalLoadingSpinner @condition={{@controller.loading}}>
      {{#if @controller.hasPermalinks}}
        <div class="d-admin-filter">
          <div class="admin-filter__input-container permalink-search">
            <TextField
              @value={{@controller.filter}}
              @placeholderKey="admin.permalink.form.filter"
              @autocorrect="off"
              @autocapitalize="off"
              class="admin-filter__input"
            />
          </div>
        </div>
      {{/if}}

      <div class="permalink-results">
        {{#if @controller.model.length}}
          <table class="d-admin-table permalinks">
            <thead>
              <th>{{i18n "admin.permalink.url"}}</th>
              <th>{{i18n "admin.permalink.destination"}}</th>
            </thead>
            <tbody>
              {{#each @controller.model as |pl|}}
                <tr
                  class={{concatClass
                    "admin-permalink-item d-admin-row__content"
                    pl.key
                  }}
                >
                  <td class="d-admin-row__overview">
                    <FlatButton
                      @title="admin.permalink.copy_to_clipboard"
                      @icon="far-clipboard"
                      @action={{fn @controller.copyUrl pl}}
                    />
                    <span
                      id="admin-permalink-{{pl.id}}"
                      class="admin-permalink-item__url"
                      title={{pl.url}}
                    >{{pl.url}}</span>
                  </td>
                  <td class="d-admin-row__detail destination">
                    {{#if pl.topic_id}}
                      <a href={{pl.topic_url}}>{{pl.topic_title}}</a>
                    {{/if}}
                    {{#if pl.post_id}}
                      <a href={{pl.post_url}}>{{pl.post_topic_title}}
                        #{{pl.post_number}}</a>
                    {{/if}}
                    {{#if pl.category_id}}
                      {{categoryLink pl.category}}
                    {{/if}}
                    {{#if pl.tag_id}}
                      <a href={{pl.tag_url}}>{{pl.tag_name}}</a>
                    {{/if}}
                    {{#if pl.external_url}}
                      {{#if pl.linkIsExternal}}
                        {{icon "up-right-from-square"}}
                      {{/if}}
                      <a href={{pl.external_url}}>{{pl.external_url}}</a>
                    {{/if}}
                    {{#if pl.user_id}}
                      <a href={{pl.user_url}}>{{pl.username}}</a>
                    {{/if}}
                  </td>
                  <td class="d-admin-row__controls">
                    <div class="d-admin-row__controls-options">
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
                          <DropdownMenu as |dropdown|>
                            <dropdown.item>
                              <DButton
                                @action={{fn @controller.destroyRecord pl}}
                                @icon="trash-can"
                                class="btn-transparent btn-danger admin-permalink-item__delete"
                                @label="admin.config_areas.permalinks.delete"
                              />
                            </dropdown.item>
                          </DropdownMenu>
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
    </ConditionalLoadingSpinner>
  </template>
);
