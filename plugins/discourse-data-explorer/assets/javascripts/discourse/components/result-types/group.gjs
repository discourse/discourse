const Group = <template>
  {{#if @ctx.group}}
    <a
      href="{{@ctx.baseuri}}/groups/{{@ctx.group.name}}"
    >{{@ctx.group.name}}</a>
  {{else}}
    {{@ctx.id}}
  {{/if}}
</template>;

export default Group;
