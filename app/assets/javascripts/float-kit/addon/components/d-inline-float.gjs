import DFloatBody from "float-kit/components/d-float-body";

const DInlineFloat = <template>
  {{#if @instance.expanded}}
    <DFloatBody
      @instance={{@instance}}
      @trapTab={{@trapTab}}
      @mainClass={{@mainClass}}
      @innerClass={{@innerClass}}
      @role={{@role}}
      @portalOutletElement={{@portalOutletElement}}
      @inline={{@inline}}
    >
      {{#if @instance.options.component}}
        <@instance.options.component
          @data={{@instance.options.data}}
          @close={{@instance.close}}
        />
      {{else}}
        {{@instance.options.content}}
      {{/if}}
    </DFloatBody>
  {{/if}}
</template>;

export default DInlineFloat;
