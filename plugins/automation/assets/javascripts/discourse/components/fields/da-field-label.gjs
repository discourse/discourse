const FieldLabel = <template>
  {{#if @label}}
    <label class="control-label">
      <span>
        {{@label}}
        {{#if @field.isRequired}}
          *
        {{/if}}
      </span>
    </label>
  {{/if}}
</template>;

export default FieldLabel;
