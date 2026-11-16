const SvgSingleColorPalettePlaceholder = <template>
  <svg
    aria-hidden="true"
    fill="none"
    viewBox="0 0 360 164"
    xmlns="http://www.w3.org/2000/svg"
    ...attributes
  >
    <rect fill="var(--secondary--preview, #fff)" height="164" width="360" />
    <rect fill={{@backgroundColor}} height="32" width="360" />
    <path
      class="color-palette-preview__sidebar"
      d={{if @tintedSidebar "M0 32H76Q60 32 60 48V164H0Z" "M0 32H60V164H0Z"}}
      fill={{@sidebarColor}}
    />
    {{#unless @tintedSidebar}}
      <path
        d="M0 32H360M60 32V164"
        stroke="var(--primary-low--preview, #e9e9e9)"
      />
    {{/unless}}
    <rect
      class="color-palette-preview__active-item"
      fill={{@activeItemColor}}
      height="18"
      rx="3"
      width="48"
      x="6"
      y="51"
    />
    <g
      class="color-palette-preview__menu"
      fill="var(--primary--preview, #222)"
      opacity="0.45"
    >
      <circle cx="14" cy="60" r="2" />
      <rect height="4" rx="2" width="26" x="22" y="58" />
      <circle cx="14" cy="78" r="2" />
      <rect height="4" rx="2" width="20" x="22" y="76" />
      <circle cx="14" cy="96" r="2" />
      <rect height="4" rx="2" width="24" x="22" y="94" />
      <circle cx="14" cy="114" r="2" />
      <rect height="4" rx="2" width="18" x="22" y="112" />
      <circle cx="14" cy="132" r="2" />
      <rect height="4" rx="2" width="22" x="22" y="130" />
    </g>
    <g fill="var(--header-primary--preview, #333)" opacity="0.325">
      <circle cx="30" cy="16" r="6" />
      <circle cx="298" cy="16" r="6" />
      <circle cx="328" cy="16" r="8" />
    </g>
    <g>
      <rect
        fill="var(--primary--preview, #222)"
        height="16"
        opacity="0.75"
        rx="8"
        width="228"
        x="84"
        y="52"
      />
      <rect
        fill="var(--primary--preview, #222)"
        height="10"
        opacity="0.45"
        rx="5"
        width="160"
        x="84"
        y="82"
      />
      <rect
        fill="var(--primary--preview, #222)"
        height="10"
        opacity="0.45"
        rx="5"
        width="194"
        x="84"
        y="100"
      />
      <rect
        fill="var(--tertiary--preview, #08c)"
        height="18"
        rx="9"
        width="58"
        x="278"
        y="126"
      />
      <g fill="var(--primary--preview, #222)" opacity="0.35">
        <rect height="12" rx="3" width="18" x="84" y="129" />
        <rect height="12" rx="3" width="18" x="112" y="129" />
        <rect height="12" rx="3" width="18" x="140" y="129" />
      </g>
    </g>
  </svg>
</template>;

export default SvgSingleColorPalettePlaceholder;
