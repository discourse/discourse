import icon from "discourse-common/helpers/d-icon";

const InputTip = <template>
  <div
    class="tip {{if @validation.failed 'bad' 'good'}}"
    id={{@id}}
    ...attributes
  >
    {{#if @validation.reason}}
      {{icon (if @validation.failed "times" "check")}}
      {{@validation.reason}}
    {{else}}
      {{#if @keepSpace}}
        &nbsp;
      {{/if}}
    {{/if}}
  </div>
</template>;

export default InputTip;
