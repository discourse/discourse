import Component from "@glimmer/component";

export default class ApiKeyUrlsModal extends Component {
  <template>
    <DModal
      @title={{i18n "admin.api.scopes.allowed_urls"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div>
          <ul>
            {{#each @model.urls as |url|}}
              <li>
                <code>{{url}}</code>
              </li>
            {{/each}}
          </ul>
        </div>
      </:body>
    </DModal>
  </template>
}
