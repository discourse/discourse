import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { get } from "@ember/helper";
import { action } from "@ember/object";
import { removeAccents } from "discourse/lib/utilities";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import type { SelectRecipeArgs } from "discourse/ui-kit/select/recipes/-internals/recipe-args";
import type {
  SelectId,
  SelectRecord,
  SelectTexts,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import I18n, { i18n } from "discourse-i18n";

declare const moment: typeof import("moment");

/** The time zone picker's arguments. */
interface DSelectTimezoneSignature {
  Args: Pick<
    DSelectSignature["Args"],
    | "ariaLabelledBy"
    | "ariaRequired"
    | "clearMode"
    | "describedBy"
    | "disabled"
    | "icon"
    | "id"
    | "invalid"
    | "noneOption"
    | "texts"
    | "variant"
  > &
    SelectRecipeArgs & {
      /** The held zone's IANA name, such as `Europe/Lisbon`. */
      value?: string | null;
      /** Receives the picked zone's IANA name, or `null` when the field is emptied. */
      onChange?: (value: string | null) => void;
    };
  Blocks: {
    /** Replaces a zone's row content; the description line is still drawn beneath it. */
    option: DSelectSignature["Blocks"]["option"];
    /** Replaces the held zone's name and offset in the closed field. */
    selection: DSelectSignature["Blocks"]["selection"];
  };
  Element: HTMLElement;
}

/** A zone as the list shows it. */
interface TimezoneRecord extends SelectRecord {
  /** The IANA name, which is the value. */
  id: string;
  /** "City, Country", or the city alone when its country is unknown or shares its name. */
  name: string;
  /** The zone's common name, such as "Brasilia Standard Time". */
  description?: string;
  /** The zone's offset from UTC, as the locale writes it. */
  offset?: string;
  /** The current time in the zone. */
  time?: string;
  /** "Tomorrow" or "Yesterday" when the zone's date differs from the device's. */
  day?: string;
  /** The group the zone is listed under. */
  group: string;
  /** The names a search can match, folded. */
  search: string;
  /** The offset in its spellings ("gmt-3", "utc-3"), folded; matched only by words with a digit. */
  offsetSearch: string;
}

const UTC = "UTC";
const DEVICE_GROUP = "device";

/** Per-locale formatters, keyed by locale and zone; building one is far slower than using it. */
const formatters = new Map<string, Intl.DateTimeFormat>();

function formatter(
  locale: string,
  timeZone: string,
  options: Intl.DateTimeFormatOptions
): Intl.DateTimeFormat | undefined {
  const key = `${locale}|${timeZone}|${JSON.stringify(options)}`;
  if (!formatters.has(key)) {
    try {
      formatters.set(
        key,
        new Intl.DateTimeFormat(locale, { timeZone, ...options })
      );
    } catch {
      // A legacy name the browser doesn't know still lists, without a description.
      return undefined;
    }
  }
  return formatters.get(key);
}

function part(
  parts: Intl.DateTimeFormatPart[] | undefined,
  type: Intl.DateTimeFormatPartTypes
): string | undefined {
  return parts?.find((p) => p.type === type)?.value;
}

/** A record's own fields, for the row block. */
function zoneOf(record: SelectRecord): TimezoneRecord {
  return record as TimezoneRecord;
}

/** A date's calendar day in a zone, as days since the epoch. */
function dayNumber(zone: string, date: Date): number | undefined {
  const parts = formatter("en-US", zone, {
    year: "numeric",
    month: "numeric",
    day: "numeric",
  })?.formatToParts(date);
  const field = (type: Intl.DateTimeFormatPartTypes) =>
    Number(part(parts, type));
  if (!parts) {
    return undefined;
  }
  return Date.UTC(field("year"), field("month") - 1, field("day")) / 86_400_000;
}

/** Folds case, accents and the typographic minus some locales write offsets with. */
function fold(text: string): string {
  return removeAccents(text).toLowerCase().replace(/−/g, "-");
}

/** The city a zone name ends with, such as "Sao Paulo" for `America/Sao_Paulo`. */
function cityOf(zone: string): string {
  return zone.split("/").at(-1)!.replace(/_/g, " ");
}

/** The countries a zone serves; Antarctic stations are left out when a country shares it. */
function countryCodesOf(zone: string): string[] {
  const codes = moment.tz.zone(zone)?.countries() ?? [];
  const settled = codes.filter((code) => code !== "AQ");
  return settled.length ? settled : codes;
}

/** Each zone's own country, from the browser's locale data; built on first use. */
let homeCountries: Map<string, string[]> | undefined;

/**
 * The country a zone belongs to. moment lists every country a zone serves (Europe/Paris serves
 * France and Monaco), while the browser's locale data names the zone's own; without that data,
 * only a zone serving a single country has one.
 */
function homeCountryOf(zone: string): string | undefined {
  if (!homeCountries) {
    homeCountries = new Map();
    for (const country of moment.tz.countries()) {
      const locale = new Intl.Locale(`und-${country}`) as Intl.Locale & {
        getTimeZones?: () => string[] | undefined;
        timeZones?: string[];
      };
      for (const timeZone of locale.getTimeZones?.() ??
        locale.timeZones ??
        []) {
        homeCountries.set(timeZone, [
          ...(homeCountries.get(timeZone) ?? []),
          country,
        ]);
      }
    }
  }
  const home = homeCountries.get(zone);
  if (home?.length === 1) {
    return home[0];
  }
  const served = countryCodesOf(zone);
  return served.length === 1 ? served[0] : undefined;
}

/** Every zone moment places in a country, the modern names, without legacy aliases. */
function countryZones(): string[] {
  const zones = new Set<string>();
  for (const country of moment.tz.countries()) {
    for (const zone of moment.tz.zonesForCountry(country)) {
      zones.add(zone);
    }
  }
  return [...zones];
}

/**
 * Picks a time zone. Zones are named by city and country, described by their common name, show
 * their offset and current time, and are grouped by region with the device's zone first.
 */
export default class DSelectTimezone extends Component<DSelectTimezoneSignature> {
  /** The picker's texts; the engine's own wording covers the rest. */
  kindTexts: SelectTexts = {
    ariaLabel: () => i18n("timezone_input.label"),
  };

  /** When the list was last opened; the times are read from it. */
  @tracked private _now = Date.now();

  /** The zones on offer, in their groups' order and by city within each. */
  get options(): TimezoneRecord[] {
    const device = this.#deviceZone;
    const deviceRegion = device?.split("/")[0];
    const zones = countryZones();
    if (!zones.includes(UTC)) {
      zones.push(UTC);
    }
    const records = zones.map((zone) =>
      this.#record(zone, zone === device ? DEVICE_GROUP : undefined)
    );
    const rank = (group: string) => {
      if (group === DEVICE_GROUP) {
        return 0;
      }
      if (group === UTC) {
        return 3;
      }
      return group === deviceRegion ? 1 : 2;
    };
    return records.sort(
      (a, b) =>
        rank(a.group) - rank(b.group) ||
        this.groupHeader(a.group).localeCompare(this.groupHeader(b.group)) ||
        a.name.localeCompare(b.name) ||
        a.id.localeCompare(b.id)
    );
  }

  get legacyKind() {
    return this.args.legacyKind ?? "timezone-input";
  }

  /** The device's zone, offered first unless it is held. */
  get #deviceZone(): string | undefined {
    const zone = moment.tz.guess(true);
    return zone && zone !== this.args.value ? zone : undefined;
  }

  @action
  groupHeader(key: SelectId): string {
    const group = String(key);
    if (group === DEVICE_GROUP) {
      return i18n("timezone_input.device");
    }
    if (group === UTC) {
      return i18n("timezone_input.regions.utc");
    }
    return i18n(`timezone_input.regions.${group.toLowerCase()}`);
  }

  @action
  matches(record: SelectRecord, term: string): boolean {
    const { search, offsetSearch } = record as TimezoneRecord;
    // Word by word, so the shown "City, Country" and words in any order both match. Only a word
    // with a digit or a sign reads offsets, or "utc" would match every zone through "utc-3"…
    return fold(term)
      .replace(/\b(gmt|utc)\s+(?=[+-])/g, "$1")
      .split(/[\s,]+/)
      .every(
        (word) =>
          search.includes(word) ||
          (/[\d+-]/.test(word) && offsetSearch.includes(word))
      );
  }

  @action
  onChange(value: SelectValue) {
    this.args.onChange?.(typeof value === "string" ? value : null);
  }

  @action
  refreshTimes() {
    this._now = Date.now();
  }

  /** Builds held zones the list doesn't offer, such as a legacy alias saved long ago. */
  @action
  resolveValues(values: SelectId[]): TimezoneRecord[] {
    return values.map((value) => this.#record(String(value)));
  }

  #record(zone: string, group?: string): TimezoneRecord {
    const locale = I18n.currentBcp47Locale;
    const now = new Date(this._now);
    const utc = zone === UTC;
    const city = utc ? i18n("timezone_input.utc") : cityOf(zone);
    const regions = new Intl.DisplayNames([locale], { type: "region" });
    const countries = utc
      ? []
      : countryCodesOf(zone).map((code) => regions.of(code) ?? code);
    const homeCode = utc ? undefined : homeCountryOf(zone);
    const home = homeCode ? (regions.of(homeCode) ?? homeCode) : undefined;
    const timeParts = formatter(locale, zone, {
      hour: "numeric",
      minute: "2-digit",
      timeZoneName: "shortOffset",
    })?.formatToParts(now);
    const offset = part(timeParts, "timeZoneName");
    const time = timeParts
      ?.filter((p) => p.type !== "timeZoneName")
      .map((p) => p.value)
      .join("")
      .trim();
    const commonName = utc
      ? undefined
      : part(
          formatter(locale, zone, {
            timeZoneName: "longGeneric",
          })?.formatToParts(now),
          "timeZoneName"
        );
    const bareOffset = offset ? fold(offset).replace(/^(gmt|utc)/, "") : "";
    const here = dayNumber(moment.tz.guess(true), now);
    const there = dayNumber(zone, now);
    const days = here != null && there != null ? there - here : 0;
    const dayText = days
      ? new Intl.RelativeTimeFormat(locale, { numeric: "auto" }).format(
          days,
          "day"
        )
      : undefined;

    return {
      id: zone,
      // A city that names its country, such as Singapore, isn't repeated.
      name:
        home && fold(home) !== fold(city)
          ? i18n("timezone_input.city_in_country", { city, country: home })
          : city,
      description: utc ? UTC : commonName,
      offset,
      time,
      day: dayText
        ? dayText[0].toLocaleUpperCase(locale) + dayText.slice(1)
        : undefined,
      group: group ?? (utc ? UTC : zone.split("/")[0]),
      search: fold(
        [
          zone.replace(/_/g, " "),
          city,
          ...countries,
          commonName,
          // Many people call UTC "GMT".
          utc ? "GMT" : undefined,
        ]
          .filter(Boolean)
          .join(" | ")
      ),
      offsetSearch: bareOffset ? `gmt${bareOffset} | utc${bareOffset}` : "",
    };
  }

  <template>
    <DSelect
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @ariaRequired={{@ariaRequired}}
      @clearMode={{@clearMode}}
      @describedBy={{@describedBy}}
      @descriptionField="description"
      @disabled={{@disabled}}
      @filterBy={{this.matches}}
      @groupBy="group"
      @groupHeader={{this.groupHeader}}
      @icon={{@icon}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @kind="select-timezone"
      @kindTexts={{this.kindTexts}}
      @legacyKind={{this.legacyKind}}
      @noneOption={{@noneOption}}
      @onChange={{this.onChange}}
      @onShow={{this.refreshTimes}}
      @options={{this.options}}
      @resolveValues={{this.resolveValues}}
      @texts={{@texts}}
      @value={{@value}}
      @variant={{@variant}}
    >
      <:option as |option config|>
        {{#if (has-block "option")}}
          {{yield option config to="option"}}
        {{else}}
          {{#let (zoneOf option.record) as |zone|}}
            <span class="d-select-timezone__option">
              <span class="d-select-timezone__place">{{option.label}}</span>
              <span class="d-select-timezone__when">
                {{#if zone.day}}
                  <span class="d-select-timezone__day">{{zone.day}}</span>
                {{/if}}
                <span class="d-select-timezone__time">{{zone.time}}</span>
              </span>
              <span class="d-select-timezone__offset">{{zone.offset}}</span>
            </span>
          {{/let}}
        {{/if}}
      </:option>
      <:selection as |option config|>
        {{#if (has-block "selection")}}
          {{yield option config to="selection"}}
        {{else}}
          <span class="d-select-timezone__selection">
            <span class="d-select-timezone__place">{{option.label}}</span>
            <span class="d-select-timezone__offset">
              {{~get (zoneOf option.record) "offset"~}}
            </span>
          </span>
        {{/if}}
      </:selection>
    </DSelect>
  </template>
}
