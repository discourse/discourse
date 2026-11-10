import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const ApiKeyUrls = <template>
  <DModal
    @closeModal={{@closeModal}}
    @title={{i18n "admin.api.scopes.allowed_urls"}}
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
</template>;

export default ApiKeyUrls;
