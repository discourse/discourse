import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";

export default class ThemesGridPlaceholder extends Component {
  randomVariant = Math.floor(Math.random() * 4);

  get themeColors() {
    if (this.args.theme.color_scheme) {
      return {
        primary: `#${this.args.theme.color_scheme.colors[0].hex}`,
        secondary: `#${this.args.theme.color_scheme.colors[1].hex}`,
        tertiary: `#${this.args.theme.color_scheme.colors[2].hex}`,
        quaternary: `#${this.args.theme.color_scheme.colors[3].hex}`,
        highlight: `#${this.args.theme.color_scheme.colors[6].hex}`,
        danger: `#${this.args.theme.color_scheme.colors[7].hex}`,
        success: `#${this.args.theme.color_scheme.colors[8].hex}`,
        love: `#${this.args.theme.color_scheme.colors[9].hex}`,
      };
    } else {
      return {
        primary: "var(--primary)",
        secondary: "var(--secondary)",
        tertiary: "var(--tertiary)",
        quaternary: "var(--quaternary)",
        highlight: "var(--highlight)",
        danger: "var(--danger)",
        success: "var(--success)",
        love: "var(--love)",
      };
    }
  }

  get safeThemeColors() {
    let colors = this.themeColors;

    return {
      primary: htmlSafe(colors.primary),
      secondary: htmlSafe(colors.secondary),
      tertiary: htmlSafe(colors.tertiary),
      quaternary: htmlSafe(colors.quaternary),
      highlight: htmlSafe(colors.highlight),
      danger: htmlSafe(colors.danger),
      success: htmlSafe(colors.success),
      love: htmlSafe(colors.love),
    };
  }

  get gradientId() {
    return `bgGradient-${this.args.theme.id}-${this.randomVariant}`;
  }

  <template>
    {{#if (eq this.randomVariant 0)}}
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="100%"
        height="100%"
        viewBox="0 0 800 200"
        preserveAspectRatio="xMidYMid slice"
      >
        <rect fill={{this.safeThemeColors.tertiary}} width="800" height="200" />
        <g transform="translate(250, -120) scale(0.45)">
          <g
            fill="none"
            stroke={{this.safeThemeColors.secondary}}
            stroke-width="1"
          >
            <path
              d="M769 229L1037 260.9M927 880L731 737 520 660 309 538 40 599 295 764 126.5 879.5 40 599-197 493 102 382-31 229 126.5 79.5-69-63"
            />
            <path
              d="M-31 229L237 261 390 382 603 493 308.5 537.5 101.5 381.5M370 905L295 764"
            />
            <path
              d="M520 660L578 842 731 737 840 599 603 493 520 660 295 764 309 538 390 382 539 269 769 229 577.5 41.5 370 105 295 -36 126.5 79.5 237 261 102 382 40 599 -69 737 127 880"
            />
            <path
              d="M520-140L578.5 42.5 731-63M603 493L539 269 237 261 370 105M902 382L539 269M390 382L102 382"
            />
            <path
              d="M-222 42L126.5 79.5 370 105 539 269 577.5 41.5 927 80 769 229 902 382 603 493 731 737M295-36L577.5 41.5M578 842L295 764M40-201L127 80M102 382L-261 269"
            />
          </g>
          <g fill={{this.safeThemeColors.tertiary}}>
            <circle cx="769" cy="229" r="5" />
            <circle cx="539" cy="269" r="5" />
            <circle cx="603" cy="493" r="5" />
            <circle cx="731" cy="737" r="5" />
            <circle cx="520" cy="660" r="5" />
            <circle cx="309" cy="538" r="5" />
            <circle cx="295" cy="764" r="5" />
            <circle cx="40" cy="599" r="5" />
            <circle cx="102" cy="382" r="5" />
            <circle cx="127" cy="80" r="5" />
            <circle cx="370" cy="105" r="5" />
            <circle cx="578" cy="42" r="5" />
            <circle cx="237" cy="261" r="5" />
            <circle cx="390" cy="382" r="5" />
          </g>
        </g>
      </svg>
    {{else if (eq this.randomVariant 1)}}
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="100%"
        height="100%"
        viewBox="0 0 800 200"
        preserveAspectRatio="xMidYMid slice"
      >
        <rect fill={{this.safeThemeColors.tertiary}} width="800" height="200" />
        <defs>
          <radialGradient
            id="{{this.gradientId}}-a"
            cx="0"
            cy="347"
            r="347"
            gradientUnits="userSpaceOnUse"
          >
            <stop offset="0" stop-color={{this.safeThemeColors.quaternary}} />
            <stop
              offset="1"
              stop-color={{this.safeThemeColors.quaternary}}
              stop-opacity="0"
            />
          </radialGradient>
          <radialGradient
            id="{{this.gradientId}}-b"
            cx="636"
            cy="347"
            r="347"
            gradientUnits="userSpaceOnUse"
          >
            <stop offset="0" stop-color={{this.safeThemeColors.tertiary}} />
            <stop
              offset="1"
              stop-color={{this.safeThemeColors.tertiary}}
              stop-opacity="0"
            />
          </radialGradient>
          <radialGradient
            id="{{this.gradientId}}-c"
            cx="600"
            cy="0"
            r="600"
            gradientUnits="userSpaceOnUse"
          >
            <stop offset="0" stop-color={{this.safeThemeColors.highlight}} />
            <stop
              offset="1"
              stop-color={{this.safeThemeColors.highlight}}
              stop-opacity="0"
            />
          </radialGradient>
          <radialGradient
            id="{{this.gradientId}}-d"
            cx="600"
            cy="347"
            r="600"
            gradientUnits="userSpaceOnUse"
          >
            <stop offset="0" stop-color={{this.safeThemeColors.quaternary}} />
            <stop
              offset="1"
              stop-color={{this.safeThemeColors.quaternary}}
              stop-opacity="0"
            />
          </radialGradient>
          <radialGradient
            id="{{this.gradientId}}-e"
            cx="0"
            cy="0"
            r="347"
            gradientUnits="userSpaceOnUse"
          >
            <stop offset="0" stop-color={{this.safeThemeColors.tertiary}} />
            <stop
              offset="1"
              stop-color={{this.safeThemeColors.tertiary}}
              stop-opacity="0"
            />
          </radialGradient>
          <radialGradient
            id="{{this.gradientId}}-f"
            cx="636"
            cy="0"
            r="347"
            gradientUnits="userSpaceOnUse"
          >
            <stop offset="0" stop-color={{this.safeThemeColors.tertiary}} />
            <stop
              offset="1"
              stop-color={{this.safeThemeColors.tertiary}}
              stop-opacity="0"
            />
          </radialGradient>
        </defs>
        <rect fill="url(#{{this.gradientId}}-a)" width="800" height="200" />
        <rect fill="url(#{{this.gradientId}}-b)" width="800" height="200" />
        <rect fill="url(#{{this.gradientId}}-c)" width="800" height="200" />
        <rect fill="url(#{{this.gradientId}}-d)" width="800" height="200" />
        <rect fill="url(#{{this.gradientId}}-e)" width="800" height="200" />
        <rect fill="url(#{{this.gradientId}}-f)" width="800" height="200" />
      </svg>
    {{else if (eq this.randomVariant 2)}}
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="100%"
        height="100%"
        viewBox="0 0 1600 800"
        preserveAspectRatio="xMidYMid slice"
      >
        <rect
          fill={{this.safeThemeColors.tertiary}}
          width="1600"
          height="800"
        />
        <g fill-opacity=".4" transform="scale(1.2)">
          <path
            fill={{this.safeThemeColors.tertiary}}
            d="M486 705.8c-109.3-21.8-223.4-32.2-335.3-19.4C99.5 692.1 49 703 0 719.8V800h843.8c-115.9-33.2-230.8-68.1-347.6-92.2C492.8 707.1 489.4 706.5 486 705.8z"
          />
          <path
            fill={{this.safeThemeColors.tertiary}}
            d="M1600 0H0v719.8c49-16.8 99.5-27.8 150.7-33.5c111.9-12.7 226-2.4 335.3 19.4c3.4 0.7 6.8 1.4 10.2 2c116.8 24 231.7 59 347.6 92.2H1600V0z"
          />
          <path
            fill={{this.safeThemeColors.quaternary}}
            d="M478.4 581c3.2 0.8 6.4 1.7 9.5 2.5c196.2 52.5 388.7 133.5 593.5 176.6c174.2 36.6 349.5 29.2 518.6-10.2V0H0v574.9c52.3-17.6 106.5-27.7 161.1-30.9C268.4 537.4 375.7 554.2 478.4 581z"
          />
          <path
            fill={{this.safeThemeColors.quaternary}}
            d="M0 0v429.4c55.6-18.4 113.5-27.3 171.4-27.7c102.8-0.8 203.2 22.7 299.3 54.5c3 1 5.9 2 8.9 3c183.6 62 365.7 146.1 562.4 192.1c186.7 43.7 376.3 34.4 557.9-12.6V0H0z"
          />
          <path
            fill={{this.safeThemeColors.highlight}}
            d="M181.8 259.4c98.2 6 191.9 35.2 281.3 72.1c2.8 1.1 5.5 2.3 8.3 3.4c171 71.6 342.7 158.5 531.3 207.7c198.8 51.8 403.4 40.8 597.3-14.8V0H0v283.2C59 263.6 120.6 255.7 181.8 259.4z"
          />
          <path
            fill={{this.safeThemeColors.highlight}}
            d="M1600 0H0v136.3c62.3-20.9 127.7-27.5 192.2-19.2c93.6 12.1 180.5 47.7 263.3 89.6c2.6 1.3 5.1 2.6 7.7 3.9c158.4 81.1 319.7 170.9 500.3 223.2c210.5 61 430.8 49 636.6-16.6V0z"
          />
          <path
            fill={{this.safeThemeColors.danger}}
            d="M454.9 86.3C600.7 177 751.6 269.3 924.1 325c208.6 67.4 431.3 60.8 637.9-5.3c12.8-4.1 25.4-8.4 38.1-12.9V0H288.1c56 21.3 108.7 50.6 159.7 82C450.2 83.4 452.5 84.9 454.9 86.3z"
          />
          <path
            fill={{this.safeThemeColors.danger}}
            d="M1600 0H498c118.1 85.8 243.5 164.5 386.8 216.2c191.8 69.2 400 74.7 595 21.1c40.8-11.2 81.1-25.2 120.3-41.7V0z"
          />
          <path
            fill={{this.safeThemeColors.success}}
            d="M1397.5 154.8c47.2-10.6 93.6-25.3 138.6-43.8c21.7-8.9 43-18.8 63.9-29.5V0H643.4c62.9 41.7 129.7 78.2 202.1 107.4C1020.4 178.1 1214.2 196.1 1397.5 154.8z"
          />
          <path
            fill={{this.safeThemeColors.success}}
            d="M1315.3 72.4c75.3-12.6 148.9-37.1 216.8-72.4h-723C966.8 71 1144.7 101 1315.3 72.4z"
          />
        </g>
      </svg>
    {{else if (eq this.randomVariant 3)}}
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="100%"
        height="100%"
        viewBox="0 0 2 1"
        preserveAspectRatio="none"
      >
        <rect fill={{this.safeThemeColors.tertiary}} width="2" height="1" />
        <defs>
          <linearGradient
            id="{{this.gradientId}}-a"
            gradientUnits="userSpaceOnUse"
            x1="0"
            x2="0"
            y1="0"
            y2="1"
          >
            <stop offset="0" stop-color={{this.safeThemeColors.tertiary}} />
            <stop offset="1" stop-color={{this.safeThemeColors.quaternary}} />
          </linearGradient>
          <linearGradient
            id="{{this.gradientId}}-b"
            gradientUnits="userSpaceOnUse"
            x1="0"
            y1="0"
            x2="0"
            y2="1"
          >
            <stop
              offset="0"
              stop-color={{this.safeThemeColors.quaternary}}
              stop-opacity="0"
            />
            <stop
              offset="1"
              stop-color={{this.safeThemeColors.highlight}}
              stop-opacity="1"
            />
          </linearGradient>
          <linearGradient
            id="{{this.gradientId}}-c"
            gradientUnits="userSpaceOnUse"
            x1="0"
            y1="0"
            x2="2"
            y2="2"
          >
            <stop
              offset="0"
              stop-color={{this.safeThemeColors.quaternary}}
              stop-opacity="0"
            />
            <stop
              offset="1"
              stop-color={{this.safeThemeColors.highlight}}
              stop-opacity="1"
            />
          </linearGradient>
        </defs>
        <rect
          x="0"
          y="0"
          fill="url(#{{this.gradientId}}-a)"
          width="2"
          height="1"
        />
        <g fill-opacity="0.5">
          <polygon fill="url(#{{this.gradientId}}-b)" points="0 1 0 0 2 0" />
          <polygon fill="url(#{{this.gradientId}}-c)" points="2 1 2 0 0 0" />
        </g>
      </svg>
    {{/if}}
  </template>
}
