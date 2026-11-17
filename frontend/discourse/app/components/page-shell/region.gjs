const PageShellRegion = <template>
  {{#if @enabled}}
    <div ...attributes>{{yield}}</div>
  {{else}}
    {{yield}}
  {{/if}}
</template>;

export default PageShellRegion;
