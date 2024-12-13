import icon from "discourse-common/helpers/d-icon";

const InputTip = <template>
  <div
    class="tip
      {{if @validation.failed 'bad' 'good'}}
      {{if @validation.reason 'has-tip'}}"
    id={{@id}}
    ...attributes
  >
    {{#if @validation.reason}}
      {{icon (if @validation.failed "xmark" "check")}}
      {{@validation.reason}}
    {{/if}}
  </div>
</template>;

export default InputTip;
