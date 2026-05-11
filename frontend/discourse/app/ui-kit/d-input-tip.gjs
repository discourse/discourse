import dIcon from "discourse/ui-kit/helpers/d-icon";

const DInputTip = <template>
  <div
    class="tip {{if @validation.failed 'bad' 'good'}}"
    id={{@id}}
    ...attributes
  >
    {{#if @validation.reason}}
      {{dIcon (if @validation.failed "xmark" "check")}}
      {{@validation.reason}}
    {{/if}}
  </div>
</template>;

export default DInputTip;
