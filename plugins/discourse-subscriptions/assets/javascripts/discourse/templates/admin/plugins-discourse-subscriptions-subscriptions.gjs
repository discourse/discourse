import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import loadingSpinner from "discourse/helpers/loading-spinner";
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
      <LoadMore
        @selector=".discourse-patrons-table tr"
        @action={{@controller.loadMore}}
      >
        <table class="table discourse-patrons-table">
          <thead>
            <tr>
              <th>
                {{i18n
                  "discourse_subscriptions.admin.subscriptions.subscription.user"
                }}
              </th>
              <th>
                {{i18n
                  "discourse_subscriptions.admin.subscriptions.subscription.subscription_id"
                }}
              </th>
              <th>
                {{i18n
                  "discourse_subscriptions.admin.subscriptions.subscription.customer"
                }}
              </th>
              <th>
                {{i18n
                  "discourse_subscriptions.admin.subscriptions.subscription.product"
                }}
              </th>
              <th>
                {{i18n
                  "discourse_subscriptions.admin.subscriptions.subscription.plan"
                }}
              </th>
              <th>
                {{i18n
                  "discourse_subscriptions.admin.subscriptions.subscription.status"
                }}
              </th>
              <th class="td-right">
                {{i18n
                  "discourse_subscriptions.admin.subscriptions.subscription.created_at"
                }}
              </th>
              <th></th>
            </tr>
          </thead>

          <tbody>
            {{#each @controller.model.data as |subscription|}}
              <tr>
                <td>
                  {{#if subscription.metadataUserExists}}
                    <a href={{subscription.subscriptionUserPath}}>
                      {{subscription.metadata.username}}
                    </a>
                  {{/if}}
                </td>
                <td>{{subscription.id}}</td>
                <td>{{subscription.customer}}</td>
                <td>{{subscription.plan.product.name}}</td>
                <td>{{subscription.plan.nickname}}</td>
                <td>{{subscription.status}}</td>
                <td class="td-right">
                  {{formatUnixDate subscription.created}}
                </td>
                <td class="td-right">
                  {{#if subscription.loading}}
                    {{loadingSpinner size="small"}}
                  {{else}}
                    <DButton
                      @disabled={{subscription.canceled}}
                      @label="cancel"
                      @action={{fn @controller.showCancelModal subscription}}
                      @icon="xmark"
                    />
                  {{/if}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </LoadMore>

      <ConditionalLoadingSpinner @condition={{@controller.loading}} />
    {{/if}}
  </template>
);
