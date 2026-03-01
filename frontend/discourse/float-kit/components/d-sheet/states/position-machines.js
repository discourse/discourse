import { EVENTS, MACHINE_NAMES, MACHINE_STATE } from "../state-machine-events";
import { GUARD_NAMES } from "./guards";

export const POSITION_MACHINES = [
  {
    name: MACHINE_NAMES.ACTIVE,
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
    name: MACHINE_NAMES.POSITION,
    initial: "out",
    states: {
      out: {
        messages: {
          [EVENTS.READY_TO_GO_FRONT]: [
            {
              guard: GUARD_NAMES.SKIP_OPENING,
              target: "position:front.status:idle",
            },
            {
              target: "position:front.status:opening",
            },
          ],
        },
      },
      front: {
        machines: [
          {
            name: "status",
            initial: "opening",
            states: {
              opening: {
                messages: {
                  [EVENTS.NEXT]: "idle",
                },
              },
              closing: {
                messages: {
                  [EVENTS.NEXT]: "position:out",
                },
              },
              idle: {
                messages: {
                  [EVENTS.READY_TO_GO_DOWN]: [
                    {
                      guard: GUARD_NAMES.SKIP_OPENING,
                      target: "position:covered.status:idle",
                    },
                    {
                      target: "position:covered.status:going-down",
                    },
                  ],
                  [EVENTS.READY_TO_GO_OUT]: "closing",
                  [EVENTS.GO_OUT]: "position:out",
                },
              },
            },
          },
        ],
      },
      covered: {
        machines: [
          {
            name: "status",
            initial: "going-down",
            states: {
              "going-down": {
                messages: {
                  [EVENTS.NEXT]: "idle",
                },
              },
              "going-up": {
                messages: {
                  [EVENTS.NEXT]: "indeterminate",
                },
              },
              indeterminate: {
                messages: {
                  [EVENTS.GOTO_IDLE]: "idle",
                  [EVENTS.GOTO_FRONT]: "position:front.status:idle",
                },
              },
              idle: {
                messages: {
                  [EVENTS.READY_TO_GO_DOWN]: [
                    {
                      guard: GUARD_NAMES.SKIP_OPENING,
                      target: "come-back",
                    },
                    {
                      target: "going-down",
                    },
                  ],
                  [EVENTS.READY_TO_GO_UP]: "going-up",
                  [EVENTS.GO_UP]: "indeterminate",
                  [EVENTS.GOTO_FRONT]: "position:front.status:idle",
                },
              },
              "come-back": {
                messages: {
                  "": "idle",
                },
              },
            },
          },
        ],
      },
    },
  },
];
