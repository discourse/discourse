import { EVENTS, MACHINE_NAMES, MACHINE_STATE } from "../state-machine-events";
import { GUARD_NAMES } from "./guards";

export const SHEET_MACHINES = [
  {
    name: MACHINE_NAMES.STAGING,
    initial: "none",
    states: {
      none: {
        messages: {
          [EVENTS.OPEN]: [
            {
              guard: GUARD_NAMES.SAFE_TO_UNMOUNT_AND_NOT_SKIP_OPENING,
              target: "opening",
            },
            {
              guard: GUARD_NAMES.SAFE_TO_UNMOUNT,
              target: "open",
            },
          ],
          [EVENTS.OPEN_PREPARED]: [
            {
              guard: GUARD_NAMES.NOT_SKIP_OPENING,
              target: "opening",
            },
            {
              target: "open",
            },
          ],
          [EVENTS.ACTUALLY_CLOSE]: {
            guard: GUARD_NAMES.NOT_SKIP_CLOSING,
            target: "closing",
          },
          [EVENTS.ACTUALLY_STEP]: "stepping",
          [EVENTS.GO_DOWN]: [
            {
              guard: GUARD_NAMES.NOT_SKIP_OPENING_MSG,
              target: "going-down",
            },
            {
              target: "go-down",
            },
          ],
          [EVENTS.GO_UP]: "going-up",
        },
      },
      open: { messages: { [EVENTS.NEXT]: "none" } },
      opening: { messages: { [EVENTS.NEXT]: "none" } },
      stepping: { messages: { [EVENTS.NEXT]: "none" } },
      closing: { messages: { [EVENTS.NEXT]: "none" } },
      "go-down": { messages: { [EVENTS.NEXT]: "none" } },
      "going-down": { messages: { [EVENTS.NEXT]: "none" } },
      "going-up": { messages: { [EVENTS.NEXT]: "none" } },
    },
  },
  {
    name: MACHINE_NAMES.LONG_RUNNING,
    initial: MACHINE_STATE.FALSE,
    states: {
      [MACHINE_STATE.FALSE]: {
        messages: { [EVENTS.TO_TRUE]: MACHINE_STATE.TRUE },
      },
      [MACHINE_STATE.TRUE]: {
        messages: { [EVENTS.TO_FALSE]: MACHINE_STATE.FALSE },
      },
    },
  },
  {
    name: MACHINE_NAMES.SKIP_OPENING,
    initial: MACHINE_STATE.FALSE,
    states: {
      [MACHINE_STATE.TRUE]: {
        messages: { [EVENTS.TO_FALSE]: MACHINE_STATE.FALSE },
      },
      [MACHINE_STATE.FALSE]: {
        messages: { [EVENTS.TO_TRUE]: MACHINE_STATE.TRUE },
      },
    },
  },
  {
    name: MACHINE_NAMES.SKIP_CLOSING,
    initial: MACHINE_STATE.FALSE,
    states: {
      [MACHINE_STATE.TRUE]: {
        messages: { [EVENTS.TO_FALSE]: MACHINE_STATE.FALSE },
      },
      [MACHINE_STATE.FALSE]: {
        messages: { [EVENTS.TO_TRUE]: MACHINE_STATE.TRUE },
      },
    },
  },
  {
    name: MACHINE_NAMES.OPENNESS,
    initial: "closed",
    states: {
      closed: {
        messages: {
          [EVENTS.READY_TO_OPEN]: [
            {
              guard: GUARD_NAMES.NOT_SKIP_OPENING_MSG,
              target: "opening",
            },
            {
              target: "open",
            },
          ],
        },
        machines: [
          {
            name: "status",
            initial: "safe-to-unmount",
            states: {
              "safe-to-unmount": {},
              pending: {
                messages: {
                  [EVENTS.OPEN]: [
                    {
                      guard: GUARD_NAMES.SKIP_OPENING,
                      target: "flushing-to-preparing-open",
                    },
                    { target: "flushing-to-preparing-opening" },
                  ],
                  "": "safe-to-unmount",
                },
              },
              "flushing-to-preparing-open": {
                messages: { "": "preparing-open" },
              },
              "flushing-to-preparing-opening": {
                messages: { "": "preparing-opening" },
              },
              "preparing-open": {},
              "preparing-opening": {},
            },
          },
        ],
      },
      opening: {
        messages: {
          [EVENTS.NEXT]: [
            {
              guard: GUARD_NAMES.OPENING_CLOSE_REQUESTED,
              target: "closing",
            },
            { target: "open" },
          ],
        },
        machines: [
          {
            name: "evaluateCloseMessage",
            silentOnly: true,
            initial: MACHINE_STATE.FALSE,
            states: {
              [MACHINE_STATE.FALSE]: {
                messages: { [EVENTS.CLOSE]: MACHINE_STATE.TRUE },
              },
              [MACHINE_STATE.TRUE]: {
                messages: { [EVENTS.CLOSE]: MACHINE_STATE.TRUE },
              },
            },
          },
        ],
      },
      open: {
        messages: {
          [EVENTS.ACTUALLY_CLOSE]: [
            {
              guard: GUARD_NAMES.SKIP_CLOSING,
              target: "openness:closed.status:pending",
            },
          ],
          [EVENTS.SWIPED_OUT]: "openness:closed.status:pending",
          [EVENTS.READY_TO_CLOSE]: [
            {
              guard: GUARD_NAMES.NOT_SKIP_CLOSING_MSG,
              target: "closing",
            },
          ],
          [EVENTS.STEP]: "open",
        },
        machines: [
          {
            name: "scroll",
            initial: "ended",
            states: {
              ended: { messages: { [EVENTS.SCROLL_START]: "ongoing" } },
              ongoing: { messages: { [EVENTS.SCROLL_END]: "ended" } },
            },
          },
          {
            name: "move",
            initial: "ended",
            states: {
              ended: { messages: { [EVENTS.MOVE_START]: "ongoing" } },
              ongoing: { messages: { [EVENTS.MOVE_END]: "ended" } },
            },
          },
          {
            name: "swipe",
            silentOnly: true,
            initial: "unstarted",
            states: {
              unstarted: { messages: { [EVENTS.SWIPE_START]: "ongoing" } },
              ongoing: { messages: { [EVENTS.SWIPE_END]: "ended" } },
              ended: {
                messages: { [EVENTS.SWIPE_START]: "ongoing" },
              },
            },
          },
          {
            name: "evaluateCloseMessage",
            silentOnly: true,
            initial: MACHINE_STATE.FALSE,
            states: {
              [MACHINE_STATE.FALSE]: {
                messages: { [EVENTS.CLOSE]: MACHINE_STATE.TRUE },
              },
              [MACHINE_STATE.TRUE]: {
                messages: { [EVENTS.CLOSE]: MACHINE_STATE.FALSE },
              },
            },
          },
          {
            name: "evaluateStepMessage",
            silentOnly: true,
            initial: MACHINE_STATE.FALSE,
            states: {
              [MACHINE_STATE.FALSE]: {
                messages: { [EVENTS.STEP]: MACHINE_STATE.TRUE },
              },
              [MACHINE_STATE.TRUE]: {
                messages: { [EVENTS.STEP]: MACHINE_STATE.FALSE },
              },
            },
          },
        ],
      },
      closing: {
        messages: { [EVENTS.NEXT]: "openness:closed.status:pending" },
      },
    },
  },
  {
    name: MACHINE_NAMES.SCROLL_CONTAINER_TOUCH,
    initial: "ended",
    states: {
      ended: { messages: { [EVENTS.TOUCH_START]: "ongoing" } },
      ongoing: { messages: { [EVENTS.TOUCH_END]: "ended" } },
    },
  },
  {
    name: MACHINE_NAMES.BACK_STUCK,
    silentOnly: true,
    initial: MACHINE_STATE.FALSE,
    states: {
      [MACHINE_STATE.FALSE]: {
        messages: { [EVENTS.STUCK_START]: MACHINE_STATE.TRUE },
      },
      [MACHINE_STATE.TRUE]: {
        messages: { [EVENTS.STUCK_END]: MACHINE_STATE.FALSE },
      },
    },
  },
  {
    name: MACHINE_NAMES.FRONT_STUCK,
    silentOnly: true,
    initial: MACHINE_STATE.FALSE,
    states: {
      [MACHINE_STATE.FALSE]: {
        messages: { [EVENTS.STUCK_START]: MACHINE_STATE.TRUE },
      },
      [MACHINE_STATE.TRUE]: {
        messages: { [EVENTS.STUCK_END]: MACHINE_STATE.FALSE },
      },
    },
  },
  {
    name: MACHINE_NAMES.ELEMENTS_READY,
    initial: MACHINE_STATE.FALSE,
    states: {
      [MACHINE_STATE.FALSE]: {
        messages: { [EVENTS.ELEMENTS_REGISTERED]: MACHINE_STATE.TRUE },
      },
      [MACHINE_STATE.TRUE]: {
        messages: { [EVENTS.RESET]: MACHINE_STATE.FALSE },
      },
    },
  },
];
