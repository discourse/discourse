import { tracked } from "@glimmer/tracking";
import { clearRender, click, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DSheet from "discourse/float-kit/components/d-sheet";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function createBleedingBackgroundSheet(onPresenceChange) {
  return {
    contentPlacementAttribute: "end",
    isCenteredTrack: false,
    isStackAnimating: false,
    setBleedingBackgroundPresent: onPresenceChange,
    stagingAttribute: "staging-none",
    tracks: "bottom",
  };
}

function createLabelSheet(prefix, calls) {
  return {
    descriptionId: `${prefix}-description`,
    isStackAnimating: false,
    registerDescription: (element) => calls.registerDescription.push(element),
    registerTitle: (element) => calls.registerTitle.push(element),
    titleId: `${prefix}-title`,
    unregisterDescription: (element) =>
      calls.unregisterDescription.push(element),
    unregisterTitle: (element) => calls.unregisterTitle.push(element),
  };
}

function createLabelCalls() {
  return {
    registerDescription: [],
    registerTitle: [],
    unregisterDescription: [],
    unregisterTitle: [],
  };
}

module(
  "Integration | Component | FloatKit | DSheet | Primitives",
  function (hooks) {
    setupRenderingTest(hooks);
    hooks.afterEach(() => sinon.restore());

    test("BleedingBackground transfers presence when its sheet changes", async function (assert) {
      const firstChanges = [];
      const secondChanges = [];
      const firstSheet = createBleedingBackgroundSheet((present) =>
        firstChanges.push(present)
      );
      const secondSheet = createBleedingBackgroundSheet((present) =>
        secondChanges.push(present)
      );
      const state = new (class {
        @tracked sheet = firstSheet;
      })();

      await render(
        <template>
          <DSheet.BleedingBackground @sheet={{state.sheet}} />
        </template>
      );

      assert.deepEqual(
        firstChanges,
        [true],
        "the initial sheet owns the background presence"
      );

      state.sheet = secondSheet;
      await settled();

      assert.deepEqual(
        firstChanges,
        [true, false],
        "the replaced sheet releases the background presence"
      );
      assert.deepEqual(
        secondChanges,
        [true],
        "the replacement sheet receives the background presence"
      );

      await clearRender();

      assert.deepEqual(
        secondChanges,
        [true, false],
        "the current sheet releases the background on teardown"
      );
    });

    test("Title and Description transfer their registrations when the sheet changes", async function (assert) {
      const firstCalls = createLabelCalls();
      const secondCalls = createLabelCalls();
      const firstSheet = createLabelSheet("first", firstCalls);
      const secondSheet = createLabelSheet("second", secondCalls);
      const state = new (class {
        @tracked sheet = firstSheet;
      })();

      await render(
        <template>
          <DSheet.Title @sheet={{state.sheet}}>Title</DSheet.Title>
          <DSheet.Description @sheet={{state.sheet}}>
            Description
          </DSheet.Description>
        </template>
      );

      const title = find("h2");
      const description = find("p");

      assert.deepEqual(
        firstCalls.registerTitle,
        [title],
        "the initial sheet registers the title"
      );
      assert.deepEqual(
        firstCalls.registerDescription,
        [description],
        "the initial sheet registers the description"
      );

      state.sheet = secondSheet;
      await settled();

      assert.deepEqual(
        firstCalls.unregisterTitle,
        [title],
        "the replaced sheet unregisters the title"
      );
      assert.deepEqual(
        firstCalls.unregisterDescription,
        [description],
        "the replaced sheet unregisters the description"
      );
      assert.deepEqual(
        secondCalls.registerTitle,
        [title],
        "the replacement sheet registers the existing title"
      );
      assert.deepEqual(
        secondCalls.registerDescription,
        [description],
        "the replacement sheet registers the existing description"
      );
      assert
        .dom(title)
        .hasAttribute("id", "second-title", "the title ID updates");
      assert
        .dom(description)
        .hasAttribute("id", "second-description", "the description ID updates");

      await clearRender();

      assert.deepEqual(
        secondCalls.unregisterTitle,
        [title],
        "the current sheet unregisters the title on teardown"
      );
      assert.deepEqual(
        secondCalls.unregisterDescription,
        [description],
        "the current sheet unregisters the description on teardown"
      );
    });

    test("element registrations survive rerenders", async function (assert) {
      const calls = createLabelCalls();
      const state = new (class {
        @tracked registrationVersion = 0;
      })();
      const sheet = {
        ...createLabelSheet("stable", calls),
        registerTitle: (element) => {
          void state.registrationVersion;
          calls.registerTitle.push(element);
        },
      };

      await render(
        <template>
          <DSheet.Title @sheet={{sheet}}>Title</DSheet.Title>
        </template>
      );

      const title = find("h2");
      state.registrationVersion++;
      await settled();

      assert.deepEqual(
        calls.registerTitle,
        [title],
        "rerendering does not register the same element again"
      );
      assert.deepEqual(
        calls.unregisterTitle,
        [],
        "rerendering does not unregister the connected element"
      );

      await clearRender();

      assert.deepEqual(
        calls.unregisterTitle,
        [title],
        "destroying the element unregisters it once"
      );
    });

    test("Header transfers its title registration when the sheet changes", async function (assert) {
      const firstCalls = createLabelCalls();
      const secondCalls = createLabelCalls();
      const firstSheet = createLabelSheet("first", firstCalls);
      const secondSheet = createLabelSheet("second", secondCalls);
      const state = new (class {
        @tracked sheet = firstSheet;
      })();

      await render(
        <template>
          <DSheet.Header @sheet={{state.sheet}}>
            <:title>Header title</:title>
          </DSheet.Header>
        </template>
      );

      const title = find(".d-sheet-header__title");

      assert.deepEqual(
        firstCalls.registerTitle,
        [title],
        "the initial sheet registers the Header title"
      );

      state.sheet = secondSheet;
      await settled();

      assert.deepEqual(
        firstCalls.unregisterTitle,
        [title],
        "the replaced sheet unregisters the Header title"
      );
      assert.deepEqual(
        secondCalls.registerTitle,
        [title],
        "the replacement sheet registers the Header title"
      );
      assert
        .dom(title)
        .hasAttribute("id", "second-title", "the Header title ID updates");

      await clearRender();

      assert.deepEqual(
        secondCalls.unregisterTitle,
        [title],
        "the current sheet unregisters the Header title on teardown"
      );
    });

    test("only an omitted action receives Trigger's present default", async function (assert) {
      const sheet = {
        id: "action-sheet",
        isPresented: false,
        isStackAnimating: false,
        role: "dialog",
      };

      await render(
        <template>
          <DSheet.Trigger @sheet={{sheet}} class="default-action">
            Default action
          </DSheet.Trigger>
          <DSheet.Trigger @sheet={{sheet}} @action={{null}} class="null-action">
            Null action
          </DSheet.Trigger>
        </template>
      );

      assert
        .dom(".default-action")
        .hasAttribute(
          "aria-haspopup",
          "dialog",
          "an omitted action defaults to present"
        );
      assert
        .dom(".null-action")
        .doesNotHaveAttribute(
          "aria-haspopup",
          "an explicit null action is not reinterpreted as present"
        );
      assert
        .dom(".null-action")
        .doesNotHaveAttribute(
          "aria-expanded",
          "an explicit null action does not expose presentation state"
        );
    });

    test("Trigger does not present for an unsupported action", async function (assert) {
      let presentationRequests = 0;
      const sheet = {
        id: "action-sheet",
        isPresented: false,
        isStackAnimating: false,
        requestPresent: () => presentationRequests++,
        role: "dialog",
      };

      await render(
        <template>
          <DSheet.Trigger
            @sheet={{sheet}}
            @action="unsupported"
            class="unsupported-action"
          >
            Unsupported action
          </DSheet.Trigger>
        </template>
      );

      await click(".unsupported-action");

      assert.strictEqual(
        presentationRequests,
        0,
        "an unsupported action is not treated as present"
      );
    });

    test("Trigger treats a null step detent as absent", async function (assert) {
      const stepDown = sinon.spy();
      const stepToDetent = sinon.spy();
      const sheet = {
        id: "action-sheet",
        isPresented: true,
        isStackAnimating: false,
        role: "dialog",
        stepDown,
        stepToDetent,
      };
      const stepAction = { type: "step", direction: "down", detent: null };

      await render(
        <template>
          <DSheet.Trigger
            @sheet={{sheet}}
            @action={{stepAction}}
            class="null-detent-step-action"
          >
            Step down
          </DSheet.Trigger>
        </template>
      );

      await click(".null-detent-step-action");

      assert.true(stepDown.calledOnce, "the direction selects the next detent");
      assert.false(
        stepToDetent.called,
        "null is not treated as an explicit detent"
      );
    });

    test("only an omitted swipeable value receives Backdrop's true default", async function (assert) {
      const swipeableValues = [];
      const sheet = {
        isStackAnimating: false,
        registerBackdrop: (_element, swipeable) =>
          swipeableValues.push(swipeable),
        registerTravelAnimation: () => () => {},
        unregisterBackdrop: () => {},
      };

      await render(
        <template>
          <DSheet.Backdrop @sheet={{sheet}} />
          <DSheet.Backdrop @sheet={{sheet}} @swipeable={{null}} />
        </template>
      );

      assert.deepEqual(
        swipeableValues,
        [true, null],
        "explicit null is preserved instead of receiving the default"
      );
    });

    test("Backdrop reserves theme-color dimming for the auto mode", async function (assert) {
      const themeColorManager = this.owner.lookup(
        "service:theme-color-manager"
      );
      const captureUnderlyingColor = sinon
        .stub(themeColorManager, "getAndStoreUnderlyingThemeColorAsRGBArray")
        .returns(false);
      const sheet = {
        isStackAnimating: false,
        registerBackdrop: () => {},
        registerTravelAnimation: () => () => {},
        state: { longRunning: { isActive: true } },
        unregisterBackdrop: () => {},
      };

      await render(
        <template>
          <DSheet.Backdrop @sheet={{sheet}} @themeColorDimming={{true}} />
        </template>
      );

      assert.false(
        captureUnderlyingColor.called,
        "an unsupported true value does not force theme-color dimming"
      );
    });
  }
);
