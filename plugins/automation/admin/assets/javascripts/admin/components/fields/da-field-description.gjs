const FieldDescription = <template>
  {{#if @description}}
    <p class="control-description">
      {{@description}}
    </p>
  {{/if}}
</template>;

export default FieldDescription;
