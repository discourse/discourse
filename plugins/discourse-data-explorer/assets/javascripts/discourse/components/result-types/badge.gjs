import dIconOrImage from "discourse/ui-kit/helpers/d-icon-or-image";

const Badge = <template>
  <a
    class="user-badge {{@ctx.badge.badgeTypeClassName}}"
    data-badge-name={{@ctx.badge.name}}
    href="{{@ctx.baseuri}}/badges/{{@ctx.badge.id}}/{{@ctx.badge.name}}"
    title={{@ctx.badge.display_name}}
  >
    {{dIconOrImage @ctx.badge}}
    <span class="badge-display-name">{{@ctx.badge.display_name}}</span>
  </a>
</template>;

export default Badge;
