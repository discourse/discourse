const Group = <template>
  {{#if @ctx.tag_group}}
    <a
      href="{{@ctx.baseuri}}/tag_groups/{{@ctx.id}}"
    >{{@ctx.tag_group.name}}</a>
  {{else}}
    {{@ctx.id}}
  {{/if}}
</template>;

export default Group;
