import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const ApiKeyUrls = <template>
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
</template>;

export default ApiKeyUrls;
