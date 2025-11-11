const FKLabel = <template>
  <label for={{@fieldId}} ...attributes>
    {{yield}}
  </label>
</template>;

export default FKLabel;
