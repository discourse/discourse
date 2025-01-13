import icon from "discourse/helpers/d-icon";

const InputTip = <template>
  <div
    class="tip {{if @validation.failed 'bad' 'good'}}"
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
