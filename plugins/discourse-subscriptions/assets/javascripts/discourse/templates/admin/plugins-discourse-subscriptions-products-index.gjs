import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import formatUnixDate from "../../helpers/format-unix-date";

export default RouteTemplate(
  <template>
    {{#if @controller.model.unconfigured}}
      <p>{{i18n "discourse_subscriptions.admin.unconfigured"}}</p>
      <p>
        <a href="https://meta.discourse.org/t/discourse-subscriptions/140818/">
          {{i18n "discourse_subscriptions.admin.on_meta"}}
        </a>
      </p>
    {{else}}
      <p class="btn-right">
        <LinkTo
          @route="adminPlugins.discourse-subscriptions.products.show"
          @model="new"
          class="btn btn-primary"
        >
          {{icon "plus"}}
          <span>
            {{i18n "discourse_subscriptions.admin.products.operations.new"}}
          </span>
        </LinkTo>
      </p>

      {{#if @controller.model}}
        <table class="table discourse-patrons-table">
          <thead>
            <th>
              {{i18n "discourse_subscriptions.admin.products.product.name"}}
            </th>
            <th>
              {{i18n
                "discourse_subscriptions.admin.products.product.created_at"
              }}
            </th>
            <th>
              {{i18n
                "discourse_subscriptions.admin.products.product.updated_at"
              }}
            </th>
            <th class="td-right">
              {{i18n "discourse_subscriptions.admin.products.product.active"}}
            </th>
            <th></th>
          </thead>

          <tbody>
            {{#each @controller.model as |product|}}
              <tr>
                <td>{{product.name}}</td>
                <td>{{formatUnixDate product.created}}</td>
                <td>{{formatUnixDate product.updated}}</td>
                <td class="td-right">{{product.active}}</td>
                <td class="td-right">
                  <div class="align-buttons">
                    <LinkTo
                      @route="adminPlugins.discourse-subscriptions.products.show"
                      @model={{product.id}}
                      class="btn no-text btn-icon"
                    >
                      {{icon "far-pen-to-square"}}
                    </LinkTo>

                    <DButton
                      @action={{routeAction "destroyProduct"}}
                      @actionParam={{product}}
                      @icon="trash-can"
                      class="btn-danger btn no-text btn-icon"
                    />
                  </div>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p>
          {{i18n "discourse_subscriptions.admin.products.product_help"}}
        </p>
      {{/if}}
    {{/if}}
  </template>
);
