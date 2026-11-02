import { tracked } from "@glimmer/tracking";
import EmberObject, { computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import type { ScreeningAction } from "discourse/admin/models/screened-email";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

/** `/admin/logs/screened_ip_addresses` record. */
export interface ScreenedIpAddressPayload {
  id: number;
  ip_address: string;
  action_name: ScreeningAction;
  match_count: number;
  last_match_at: string | null;
  created_at: string;
}

/** The add form builds records with only an address and action. */
export interface ScreenedIpAddressFields {
  id?: number;
  ip_address: string;
  match_count: number;
  last_match_at: string | null;
  created_at: string;
  editing?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface ScreenedIpAddress extends ScreenedIpAddressFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class ScreenedIpAddress extends EmberObject {
  static findAll(filter?: string | null): Promise<ScreenedIpAddress[]> {
    return ajax("/admin/logs/screened_ip_addresses.json", {
      data: { filter },
    }).then((screened_ips: ScreenedIpAddressPayload[]) =>
      screened_ips.map((b) => ScreenedIpAddress.create(b))
    );
  }

  @tracked action_name!: ScreeningAction;

  @dependentKeyCompat
  get isBlocked(): boolean {
    return this.action_name === "block";
  }

  @computed("action_name")
  get actionName(): string {
    return i18n(`admin.logs.screened_ips.actions.${this.action_name}`);
  }

  @computed("ip_address")
  get isRange(): boolean {
    return this.ip_address.indexOf("/") > 0;
  }

  save(): Promise<{ screened_ip_address: ScreenedIpAddressPayload }> {
    return ajax(
      "/admin/logs/screened_ip_addresses" +
        (this.id ? "/" + this.id : "") +
        ".json",
      {
        type: this.id ? "PUT" : "POST",
        data: {
          ip_address: this.ip_address,
          action_name: this.action_name,
        },
      }
    );
  }

  /** Deletes the record on the server, unlike EmberObject's `destroy`. */
  destroy(this: never): never;
  destroy(): Promise<{ success: string }>;
  destroy(): Promise<{ success: string }> {
    return ajax("/admin/logs/screened_ip_addresses/" + this.id + ".json", {
      type: "DELETE",
    });
  }
}
