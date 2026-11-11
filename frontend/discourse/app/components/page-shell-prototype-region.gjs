const PageShellPrototypeRegion = <template>
  {{#if @enabled}}
    <div ...attributes>{{yield}}</div>
  {{else}}
    {{yield}}
  {{/if}}
</template>;

export default PageShellPrototypeRegion;
