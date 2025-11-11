import { htmlSafe } from "@ember/template";

const FormError = <template>
  {{#if @error}}
    <div class="alert alert-error form-errors">
      {{htmlSafe @error}}
    </div>
  {{/if}}
</template>;

export default FormError;
