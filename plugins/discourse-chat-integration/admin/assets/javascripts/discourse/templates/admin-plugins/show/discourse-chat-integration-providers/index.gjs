import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

const providerTitle = (provider) =>
  i18n(`chat_integration.provider.${provider.name}.title`);

export default <template>
  <div class="admin-detail chat-integration-providers">
    <DPageSubheader
      @descriptionLabel={{i18n "chat_integration.providers_description"}}
      @learnMoreUrl="https://meta.discourse.org/t/chat-integration-plugin/66522"
    >
      <:actions as |actions|>
        {{#if @model.disabled_providers.length}}
          <actions.Primary
            class="chat-integration-providers__add"
            @icon="plus"
            @label="chat_integration.add_provider"
            @route="adminPlugins.show.discourse-chat-integration-providers.new"
          />
        {{/if}}
      </:actions>
    </DPageSubheader>

    {{#if @model.enabled_providers.length}}
      <table class="d-table chat-integration-providers__table">
        <thead class="d-table__header">
          <tr class="d-table__row">
            <th class="d-table__header-cell">
              {{i18n "chat_integration.providers_table.provider"}}
            </th>
            <th class="d-table__header-cell">
              {{i18n "chat_integration.providers_table.channels"}}
            </th>
            <th class="d-table__header-cell"></th>
          </tr>
        </thead>
        <tbody class="d-table__body">
          {{#each @model.enabled_providers as |provider|}}
            <tr
              class="d-table__row chat-integration-providers__row"
              data-provider={{provider.name}}
            >
              <td class="d-table__cell --overview">
                <strong>{{providerTitle provider}}</strong>
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">
                  {{i18n "chat_integration.providers_table.channels"}}
                </div>
                {{provider.channel_count}}
              </td>
              <td class="d-table__cell --controls">
                <DButton
                  class="btn-default btn-small chat-integration-providers__edit"
                  @label="chat_integration.edit_provider"
                  @route="adminPlugins.show.discourse-chat-integration-providers.edit"
                  @routeModels={{provider.name}}
                />
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <AdminConfigAreaEmptyList
        @ctaClass="chat-integration-providers__empty-add"
        @ctaLabel="chat_integration.add_provider"
        @ctaRoute="adminPlugins.show.discourse-chat-integration-providers.new"
        @emptyLabel="chat_integration.empty_state.title"
      />
    {{/if}}
  </div>
</template>
