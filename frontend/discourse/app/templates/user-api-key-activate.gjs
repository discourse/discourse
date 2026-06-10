import Form from "discourse/components/form";
import UserApiKeyDeviceCodeInput from "discourse/components/user-api-key-device-code-input";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
  {{hideApplicationSidebar}}
  {{hideApplicationFooter}}

  <div class="authorize-api-key">
    {{#if @controller.showComplete}}
      {{#if @controller.page.denied}}
        <h1>{{i18n "user_api_key.device.denied"}}</h1>
      {{else}}
        <h1>{{i18n "user_api_key.device.complete"}}</h1>
      {{/if}}

      <p>{{i18n "user_api_key.device.return_to_cli"}}</p>
    {{else if @controller.showAuthorize}}
      <h1>
        {{i18n
          "user_api_key.device.authorize_title"
          application_name=@controller.page.device_auth.application_name
        }}
      </h1>

      {{#if @controller.page.expired_code}}
        <p class="error-message">{{i18n "user_api_key.device.expired_code"}}</p>
      {{/if}}

      {{#if @controller.error}}
        <p class="error-message">{{@controller.error}}</p>
      {{/if}}

      {{#if @controller.page.no_trust_level}}
        <p class="error-message">{{i18n "user_api_key.no_trust_level"}}</p>
      {{else}}
        <div class="authorize-api-key__user">
          <span class="authorize-api-key__user-label">
            {{i18n "user_api_key.logged_in_as"}}
          </span>
          <img
            class="avatar"
            src={{@controller.avatarUrl}}
            width="24"
            height="24"
            alt=""
          />
          <span class="authorize-api-key__username">
            {{@controller.page.current_user.username}}
          </span>
        </div>

        <div class="authorize-api-key__summary">
          <div class="authorize-api-key__permissions">
            <p class="authorize-api-key__permissions-header">
              {{i18n
                "user_api_key.permissions_header"
                application_name=@controller.page.device_auth.application_name
              }}
            </p>
            <ul class="authorize-api-key__scopes">
              {{#each @controller.page.device_auth.localized_scopes as |scope|}}
                <li>{{scope}}</li>
              {{/each}}
            </ul>
          </div>

          {{#if @controller.page.device_auth.write_scope}}
            <div
              class="authorize-api-key__write-warning authorize-api-key__summary-notice"
            >
              <p>{{i18n "user_api_key.write_scope_warning"}}</p>
            </div>
          {{/if}}

          {{#if @controller.page.device_auth.unregistered_client}}
            <div
              class="authorize-api-key__unregistered-warning authorize-api-key__summary-notice"
            >
              <p>{{i18n "user_api_key.device.unregistered_app_warning"}}</p>
            </div>
          {{/if}}

          {{#if @controller.deviceExpiresAt}}
            <div
              class="authorize-api-key__expiry authorize-api-key__summary-detail"
            >
              <p>
                {{i18n
                  "user_api_key.device.expiry_notice"
                  application_name=@controller.page.device_auth.application_name
                  expires_at=@controller.deviceExpiresAt
                }}
              </p>
            </div>
          {{else}}
            <div
              class="authorize-api-key__expiry-warning authorize-api-key__summary-notice"
            >
              <p>{{i18n "user_api_key.device.no_expiry_warning"}}</p>
            </div>
          {{/if}}
        </div>

        {{#unless @controller.page.expired_code}}
          {{#if @controller.page.request_token}}
            <Form
              @data={{@controller.codeFormData}}
              @onSubmit={{@controller.approve}}
              @onRegisterApi={{@controller.registerCodeFormApi}}
              class="authorize-api-key__code-form"
              as |form|
            >
              <form.Field
                @name="code"
                @title={{i18n "user_api_key.device.code"}}
                @description={{i18n "user_api_key.device.enter_code"}}
                @showOptional={{false}}
                @format="full"
                @type="custom"
                @validate={{@controller.validateCode}}
                as |field|
              >
                <field.Control>
                  <UserApiKeyDeviceCodeInput
                    id={{field.id}}
                    @onChange={{field.set}}
                    @onFill={{field.set}}
                    aria-describedby={{field.describedBy}}
                    aria-invalid={{if field.error "true" "false"}}
                  />
                </field.Control>
              </form.Field>

              <form.Actions>
                <form.Submit
                  @label="user_api_key.authorize"
                  @disabled={{@controller.isLoading}}
                />
              </form.Actions>
            </Form>
          {{else}}
            <div class="authorize-api-key__buttons">
              <Form
                @data={{@controller.approvalFormData}}
                @onSubmit={{@controller.approveWithApprovalToken}}
                as |form|
              >
                <form.Actions>
                  <form.Submit
                    @label="user_api_key.authorize"
                    @disabled={{@controller.isLoading}}
                  />
                </form.Actions>
              </Form>
              <DButton
                @disabled={{@controller.isLoading}}
                @action={{@controller.deny}}
                @label="user_api_key.deny"
                class="btn-default"
              />
            </div>
          {{/if}}
        {{/unless}}
      {{/if}}
    {{else}}
      <h1>{{i18n "user_api_key.device.title"}}</h1>

      {{#if @controller.page.expired_code}}
        <p class="error-message">{{i18n "user_api_key.device.expired_code"}}</p>
      {{/if}}

      {{#if @controller.error}}
        <p class="error-message">{{@controller.error}}</p>
      {{/if}}

      {{#unless @controller.page.expired_code}}
        <Form
          @data={{@controller.codeFormData}}
          @onSubmit={{@controller.submitCode}}
          @onRegisterApi={{@controller.registerCodeFormApi}}
          class="authorize-api-key__code-form"
          as |form|
        >
          <form.Field
            @name="code"
            @title={{i18n "user_api_key.device.code"}}
            @description={{i18n "user_api_key.device.enter_code"}}
            @showOptional={{false}}
            @format="full"
            @type="custom"
            @validate={{@controller.validateCode}}
            as |field|
          >
            <field.Control>
              <UserApiKeyDeviceCodeInput
                id={{field.id}}
                @onChange={{field.set}}
                @onFill={{field.set}}
                aria-describedby={{field.describedBy}}
                aria-invalid={{if field.error "true" "false"}}
              />
            </field.Control>
          </form.Field>

          <form.Actions>
            <form.Submit
              @label="user_api_key.device.continue"
              @disabled={{@controller.isLoading}}
            />
          </form.Actions>
        </Form>
      {{/unless}}
    {{/if}}
  </div>
</template>
