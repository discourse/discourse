import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

<template>
  <DModal
    @title={{i18n
      "discourse_ai.mcp_servers.tools_modal.title"
      name=@model.serverName
    }}
    @closeModal={{@closeModal}}
    @bodyClass="ai-mcp-server-tools-modal__body"
    class="ai-mcp-server-tools-modal"
  >
    <:body>
      <p class="ai-mcp-server-tools-modal__summary">
        {{i18n
          "discourse_ai.mcp_servers.tools_modal.summary"
          count=@model.tools.length
        }}
      </p>

      {{#each @model.tools as |tool|}}
        <section class="ai-mcp-server-tools-modal__tool">
          <div class="ai-mcp-server-tools-modal__header">
            <div class="ai-mcp-server-tools-modal__title">
              {{if tool.title tool.title tool.name}}
            </div>
            <code class="ai-mcp-server-tools-modal__name">{{tool.name}}</code>
          </div>

          {{#if tool.description}}
            <p class="ai-mcp-server-tools-modal__description">
              {{tool.description}}
            </p>
          {{/if}}

          {{#if tool.parameters.length}}
            <h3 class="ai-mcp-server-tools-modal__parameters-title">
              {{i18n "discourse_ai.mcp_servers.tools_modal.parameters"}}
            </h3>

            <ul class="ai-mcp-server-tools-modal__parameters">
              {{#each tool.parameters as |parameter|}}
                <li class="ai-mcp-server-tools-modal__parameter">
                  <div class="ai-mcp-server-tools-modal__parameter-meta">
                    <code class="ai-mcp-server-tools-modal__parameter-name">
                      {{parameter.name}}
                    </code>
                    <span class="ai-mcp-server-tools-modal__parameter-type">
                      {{parameter.type}}
                    </span>
                    {{#if parameter.required}}
                      <span
                        class="ai-mcp-server-tools-modal__parameter-required"
                      >
                        {{i18n "discourse_ai.mcp_servers.tools_modal.required"}}
                      </span>
                    {{/if}}
                  </div>

                  {{#if parameter.description}}
                    <div
                      class="ai-mcp-server-tools-modal__parameter-description"
                    >
                      {{parameter.description}}
                    </div>
                  {{/if}}
                </li>
              {{/each}}
            </ul>
          {{else}}
            <p class="ai-mcp-server-tools-modal__no-parameters">
              {{i18n "discourse_ai.mcp_servers.tools_modal.no_parameters"}}
            </p>
          {{/if}}
        </section>
      {{/each}}
    </:body>
  </DModal>
</template>
