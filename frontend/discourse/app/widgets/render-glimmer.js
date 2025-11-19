import deprecated from "discourse/lib/deprecated";

/**
 * @deprecated use Glimmer components instead
 */
export function registerWidgetShim() {
  deprecated(
    "`registerWidgetShim` has been decommissioned. Your site may not work properly. See https://meta.discourse.org/t/375332/1"
  );
}
