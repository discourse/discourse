/**
 * IMPORTANT: The widget rendering system has been decommissioned.
 *
 * This file is maintained only to prevent breaking imports in existing third-party customizations.
 * New code should not use this component or the widget system.
 */

/**
 * This is a shim used to prevent breaking imports from "virtual-dom"
 */
export {
  warnWidgetsDecommissioned as create,
  warnWidgetsDecommissioned as h,
} from "discourse/widgets/widget";
