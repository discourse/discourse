import { trustHTML } from "@ember/template";

const FormError = <template>
  {{#if @error}}
    <div class="alert alert-error form-errors">
      {{trustHTML @error}}
    </div>
  {{/if}}
</template>;

export default FormError;
