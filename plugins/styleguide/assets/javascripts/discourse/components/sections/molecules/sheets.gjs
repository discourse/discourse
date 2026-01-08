import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DCard from "discourse/float-kit/components/d-card";
import DSheet from "discourse/float-kit/components/d-sheet";
import DSheetWithDetent from "discourse/float-kit/components/d-sheet-with-detent";
import DSheetWithStacking from "discourse/float-kit/components/d-sheet-with-stacking";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class Sheets extends Component {
  @service toasts;

  // Form values for Cat Profile Builder
  @tracked catName = "Luna";
  @tracked catAge = "adult";
  @tracked catBreed = "mixed";
  @tracked catFurLength = "short";
  @tracked catSize = "medium";
  @tracked catColor1 = "#f5a623";
  @tracked catColor2 = "#ffffff";
  @tracked catColor3 = "#4a4a4a";
  @tracked catPersonality = ["cuddly", "curious"];
  @tracked catLifestyle = ["apartment", "indoor"];
  @tracked
  catDescription =
    "A gentle, affectionate companion who loves sunny windowsills and quiet evenings curled up on the couch.";

  @action
  updateFormField(field, event) {
    this[field] = event.target.value;
  }

  @action
  exampleToastAction() {
    alert("exampleToastAction");
  }

  @action
  showToast() {
    this.toasts.success({
      showProgressBar: true,
      data: {
        cancel: true,
        action: {
          label: "Action",
          onClick: this.exampleToastAction,
        },
        title: "Hello",
        message: "This is a toast",
      },
    });
  }

  @action
  toggleCheckbox(field, value) {
    const current = this[field];
    if (current.includes(value)) {
      this[field] = current.filter((v) => v !== value);
    } else {
      this[field] = [...current, value];
    }
  }

  colorStyle(color) {
    return htmlSafe(`--color: ${color}`);
  }

  <template>
    <StyleguideExample @title="Sheets">
      {{! <StyleguideComponent @tag="bottom">
        <:sample>
          <DSheetBottom>
            test
          </DSheetBottom>
        </:sample>
      </StyleguideComponent>}}

      <StyleguideComponent @tag="with-detent">
        <:sample>
          <DSheetWithDetent>
            <:root as |sheet|>
              <sheet.Trigger @action="present">
                Present
              </sheet.Trigger>
            </:root>
            <:content as |sheet|>
              <input />

              <DSheet.Scroll.Root as |controller|>
                <DSheet.Scroll.View
                  class="SheetWithDetent-scrollView"
                  @scrollGesture={{if sheet.reachedLastDetent "auto" false}}
                  @scrollGestureTrap={{hash yEnd=true}}
                  @safeArea="layout-viewport"
                  @onScrollStart={{hash dismissKeyboard=true}}
                  @controller={{controller}}
                >
                  <DSheet.Scroll.Content
                    class="SheetWithDetent-scrollContent"
                    @controller={{controller}}
                  >
                    <ul>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                      <li>Foo</li>
                    </ul>
                  </DSheet.Scroll.Content>
                </DSheet.Scroll.View>
              </DSheet.Scroll.Root>

              {{! <sheet.Trigger @action="step">
                Step
              </sheet.Trigger>
              <sheet.Trigger @action="dismiss">
                Dismiss
              </sheet.Trigger> }}

            </:content>
          </DSheetWithDetent>
        </:sample>
      </StyleguideComponent>

      <StyleguideComponent @tag="card">
        <:sample>
          <DCard>
            <:root as |sheet|>
              <sheet.Trigger @action="present">
                Present
              </sheet.Trigger>
            </:root>
            <:content as |sheet|>

            </:content>
          </DCard>
        </:sample>
      </StyleguideComponent>

      <StyleguideComponent @tag="toast">
        <:sample>
          <DButton @action={{this.showToast}}>Show toast</DButton>
        </:sample>
      </StyleguideComponent>

      <StyleguideComponent @tag="stacks">
        <:sample>
          <DSheetWithStacking>
            <:root as |Trigger|>
              <Trigger>Present</Trigger>
            </:root>
            <:content>FIRST</:content>
            <:nestedContent>SECOND</:nestedContent>
          </DSheetWithStacking>
        </:sample>
      </StyleguideComponent>

      {{!-- <StyleguideComponent @tag="with-keyboard">
        <:sample>
          <DSheetWithKeyboard.Root as |root|>
            <root.Trigger class="ExampleSheetWithKeyboard-presentTrigger">
              Build Your Ideal Cat
            </root.Trigger>
            <root.Portal>
              <root.View as |view|>
                <view.Backdrop />
                <view.Content class="ExampleSheetWithKeyboard-content">
                  <div class="ExampleSheetWithKeyboard-header">
                    <root.Trigger
                      class="ExampleSheetWithKeyboard-cancelButton"
                      @action="dismiss"
                    >
                      Cancel
                    </root.Trigger>
                    <h2 class="ExampleSheetWithKeyboard-title">
                      Build Your Ideal Cat
                    </h2>
                    <root.Trigger
                      class="ExampleSheetWithKeyboard-saveButton"
                      @action="dismiss"
                    >
                      Save
                    </root.Trigger>
                  </div>
                  <root.ScrollView>
                    <div class="ExampleSheetWithKeyboard-info">
                      <h3 class="ExampleSheetWithKeyboard-details">
                        Cat Profile
                      </h3>
                      <div class="ExampleSheetWithKeyboard-form">
                        {{! Cat Name }}
                        <div class="ExampleSheetWithKeyboard-field">
                          <label
                            for="cat-name"
                            class="ExampleSheetWithKeyboard-label"
                          >
                            Cat Name
                          </label>
                          <p class="ExampleSheetWithKeyboard-labelDescription">
                            What would you name your ideal cat?
                          </p>
                          <input
                            class="ExampleSheetWithKeyboard-input"
                            id="cat-name"
                            name="catName"
                            type="text"
                            placeholder="Whiskers, Luna, Oliver..."
                            value={{this.catName}}
                            {{on "input" (fn this.updateFormField "catName")}}
                          />
                        </div>

                        {{! Age Preference }}
                        <div class="ExampleSheetWithKeyboard-field">
                          <div class="ExampleSheetWithKeyboard-label">
                            Age Preference
                          </div>
                          <p class="ExampleSheetWithKeyboard-labelDescription">
                            What life stage are you looking for?
                          </p>
                          <div class="ExampleSheetWithKeyboard-radioGroup">
                            <label class="ExampleSheetWithKeyboard-radioLabel">
                              <input
                                type="radio"
                                name="catAge"
                                value="kitten"
                                checked={{eq this.catAge "kitten"}}
                                {{on
                                  "change"
                                  (fn this.updateFormField "catAge")
                                }}
                              />
                              <span>Kitten (0-1 year)</span>
                            </label>
                            <label class="ExampleSheetWithKeyboard-radioLabel">
                              <input
                                type="radio"
                                name="catAge"
                                value="adult"
                                checked={{eq this.catAge "adult"}}
                                {{on
                                  "change"
                                  (fn this.updateFormField "catAge")
                                }}
                              />
                              <span>Adult (1-7 years)</span>
                            </label>
                            <label class="ExampleSheetWithKeyboard-radioLabel">
                              <input
                                type="radio"
                                name="catAge"
                                value="senior"
                                checked={{eq this.catAge "senior"}}
                                {{on
                                  "change"
                                  (fn this.updateFormField "catAge")
                                }}
                              />
                              <span>Senior (7+ years)</span>
                            </label>
                          </div>
                        </div>

                        {{! Breed }}
                        <div class="ExampleSheetWithKeyboard-field">
                          <label
                            for="cat-breed"
                            class="ExampleSheetWithKeyboard-label"
                          >
                            Breed
                          </label>
                          <p class="ExampleSheetWithKeyboard-labelDescription">
                            Select your preferred breed.
                          </p>
                          <select
                            class="ExampleSheetWithKeyboard-select"
                            id="cat-breed"
                            name="catBreed"
                            value={{this.catBreed}}
                            {{on "change" (fn this.updateFormField "catBreed")}}
                          >
                            <option value="mixed">Mixed / Rescue</option>
                            <option value="persian">Persian</option>
                            <option value="siamese">Siamese</option>
                            <option value="maine-coon">Maine Coon</option>
                            <option value="british-shorthair">British Shorthair</option>
                            <option value="ragdoll">Ragdoll</option>
                            <option value="bengal">Bengal</option>
                            <option value="abyssinian">Abyssinian</option>
                            <option value="scottish-fold">Scottish Fold</option>
                            <option value="sphynx">Sphynx</option>
                          </select>
                        </div>

                        {{! Personality Traits }}
                        <div class="ExampleSheetWithKeyboard-field">
                          <div class="ExampleSheetWithKeyboard-label">
                            Personality Traits
                          </div>
                          <p class="ExampleSheetWithKeyboard-labelDescription">
                            Select the traits that matter most to you.
                          </p>
                          <div class="ExampleSheetWithKeyboard-checkboxGroup">
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes
                                  this.catPersonality
                                  "playful"
                                }}
                                {{on
                                  "change"
                                  (fn
                                    this.toggleCheckbox
                                    "catPersonality"
                                    "playful"
                                  )
                                }}
                              />
                              <span>Playful</span>
                            </label>
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes this.catPersonality "calm"}}
                                {{on
                                  "change"
                                  (fn
                                    this.toggleCheckbox "catPersonality" "calm"
                                  )
                                }}
                              />
                              <span>Calm</span>
                            </label>
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes
                                  this.catPersonality
                                  "independent"
                                }}
                                {{on
                                  "change"
                                  (fn
                                    this.toggleCheckbox
                                    "catPersonality"
                                    "independent"
                                  )
                                }}
                              />
                              <span>Independent</span>
                            </label>
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes
                                  this.catPersonality
                                  "cuddly"
                                }}
                                {{on
                                  "change"
                                  (fn
                                    this.toggleCheckbox
                                    "catPersonality"
                                    "cuddly"
                                  )
                                }}
                              />
                              <span>Cuddly</span>
                            </label>
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes
                                  this.catPersonality
                                  "curious"
                                }}
                                {{on
                                  "change"
                                  (fn
                                    this.toggleCheckbox
                                    "catPersonality"
                                    "curious"
                                  )
                                }}
                              />
                              <span>Curious</span>
                            </label>
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes this.catPersonality "vocal"}}
                                {{on
                                  "change"
                                  (fn
                                    this.toggleCheckbox "catPersonality" "vocal"
                                  )
                                }}
                              />
                              <span>Vocal</span>
                            </label>
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes this.catPersonality "shy"}}
                                {{on
                                  "change"
                                  (fn
                                    this.toggleCheckbox "catPersonality" "shy"
                                  )
                                }}
                              />
                              <span>Shy</span>
                            </label>
                          </div>
                        </div>

                        {{! Fur Length }}
                        <div class="ExampleSheetWithKeyboard-field">
                          <div class="ExampleSheetWithKeyboard-label">
                            Fur Length
                          </div>
                          <p class="ExampleSheetWithKeyboard-labelDescription">
                            What coat length do you prefer?
                          </p>
                          <div class="ExampleSheetWithKeyboard-radioGroup">
                            <label class="ExampleSheetWithKeyboard-radioLabel">
                              <input
                                type="radio"
                                name="catFurLength"
                                value="hairless"
                                checked={{eq this.catFurLength "hairless"}}
                                {{on
                                  "change"
                                  (fn this.updateFormField "catFurLength")
                                }}
                              />
                              <span>Hairless</span>
                            </label>
                            <label class="ExampleSheetWithKeyboard-radioLabel">
                              <input
                                type="radio"
                                name="catFurLength"
                                value="short"
                                checked={{eq this.catFurLength "short"}}
                                {{on
                                  "change"
                                  (fn this.updateFormField "catFurLength")
                                }}
                              />
                              <span>Short</span>
                            </label>
                            <label class="ExampleSheetWithKeyboard-radioLabel">
                              <input
                                type="radio"
                                name="catFurLength"
                                value="medium"
                                checked={{eq this.catFurLength "medium"}}
                                {{on
                                  "change"
                                  (fn this.updateFormField "catFurLength")
                                }}
                              />
                              <span>Medium</span>
                            </label>
                            <label class="ExampleSheetWithKeyboard-radioLabel">
                              <input
                                type="radio"
                                name="catFurLength"
                                value="long"
                                checked={{eq this.catFurLength "long"}}
                                {{on
                                  "change"
                                  (fn this.updateFormField "catFurLength")
                                }}
                              />
                              <span>Long</span>
                            </label>
                          </div>
                        </div>

                        {{! Size }}
                        <div class="ExampleSheetWithKeyboard-field">
                          <div class="ExampleSheetWithKeyboard-label">
                            Size
                          </div>
                          <p class="ExampleSheetWithKeyboard-labelDescription">
                            What size cat do you prefer?
                          </p>
                          <div class="ExampleSheetWithKeyboard-radioGroup">
                            <label class="ExampleSheetWithKeyboard-radioLabel">
                              <input
                                type="radio"
                                name="catSize"
                                value="small"
                                checked={{eq this.catSize "small"}}
                                {{on
                                  "change"
                                  (fn this.updateFormField "catSize")
                                }}
                              />
                              <span>Small (5-8 lbs)</span>
                            </label>
                            <label class="ExampleSheetWithKeyboard-radioLabel">
                              <input
                                type="radio"
                                name="catSize"
                                value="medium"
                                checked={{eq this.catSize "medium"}}
                                {{on
                                  "change"
                                  (fn this.updateFormField "catSize")
                                }}
                              />
                              <span>Medium (8-12 lbs)</span>
                            </label>
                            <label class="ExampleSheetWithKeyboard-radioLabel">
                              <input
                                type="radio"
                                name="catSize"
                                value="large"
                                checked={{eq this.catSize "large"}}
                                {{on
                                  "change"
                                  (fn this.updateFormField "catSize")
                                }}
                              />
                              <span>Large (12+ lbs)</span>
                            </label>
                          </div>
                        </div>

                        {{! Coat Colors }}
                        <div
                          class="ExampleSheetWithKeyboard-field fieldType-color"
                        >
                          <div class="ExampleSheetWithKeyboard-label">
                            Coat Colors
                          </div>
                          <p class="ExampleSheetWithKeyboard-labelDescription">
                            Pick your preferred coat colors.
                          </p>
                          <div class="ExampleSheetWithKeyboard-colorInputs">
                            <div
                              class="ExampleSheetWithKeyboard-colorInputWrapper"
                            >
                              <input
                                class="ExampleSheetWithKeyboard-colorInput"
                                id="cat-color1"
                                name="color1"
                                type="color"
                                value={{this.catColor1}}
                                {{on
                                  "input"
                                  (fn this.updateFormField "catColor1")
                                }}
                              />
                              <div
                                class="ExampleSheetWithKeyboard-colorInputReplacement"
                                style={{this.colorStyle this.catColor1}}
                              ></div>
                            </div>
                            <div
                              class="ExampleSheetWithKeyboard-colorInputWrapper"
                            >
                              <input
                                class="ExampleSheetWithKeyboard-colorInput"
                                id="cat-color2"
                                name="color2"
                                type="color"
                                value={{this.catColor2}}
                                {{on
                                  "input"
                                  (fn this.updateFormField "catColor2")
                                }}
                              />
                              <div
                                class="ExampleSheetWithKeyboard-colorInputReplacement"
                                style={{this.colorStyle this.catColor2}}
                              ></div>
                            </div>
                            <div
                              class="ExampleSheetWithKeyboard-colorInputWrapper"
                            >
                              <input
                                class="ExampleSheetWithKeyboard-colorInput"
                                id="cat-color3"
                                name="color3"
                                type="color"
                                value={{this.catColor3}}
                                {{on
                                  "input"
                                  (fn this.updateFormField "catColor3")
                                }}
                              />
                              <div
                                class="ExampleSheetWithKeyboard-colorInputReplacement"
                                style={{this.colorStyle this.catColor3}}
                              ></div>
                            </div>
                          </div>
                        </div>

                        {{! Lifestyle Compatibility }}
                        <div class="ExampleSheetWithKeyboard-field">
                          <div class="ExampleSheetWithKeyboard-label">
                            Lifestyle Compatibility
                          </div>
                          <p class="ExampleSheetWithKeyboard-labelDescription">
                            Select what applies to your living situation.
                          </p>
                          <div class="ExampleSheetWithKeyboard-checkboxGroup">
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes
                                  this.catLifestyle
                                  "apartment"
                                }}
                                {{on
                                  "change"
                                  (fn
                                    this.toggleCheckbox
                                    "catLifestyle"
                                    "apartment"
                                  )
                                }}
                              />
                              <span>Apartment-friendly</span>
                            </label>
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes
                                  this.catLifestyle
                                  "children"
                                }}
                                {{on
                                  "change"
                                  (fn
                                    this.toggleCheckbox
                                    "catLifestyle"
                                    "children"
                                  )
                                }}
                              />
                              <span>Good with children</span>
                            </label>
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes this.catLifestyle "dogs"}}
                                {{on
                                  "change"
                                  (fn this.toggleCheckbox "catLifestyle" "dogs")
                                }}
                              />
                              <span>Good with dogs</span>
                            </label>
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes this.catLifestyle "cats"}}
                                {{on
                                  "change"
                                  (fn this.toggleCheckbox "catLifestyle" "cats")
                                }}
                              />
                              <span>Good with other cats</span>
                            </label>
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes this.catLifestyle "indoor"}}
                                {{on
                                  "change"
                                  (fn
                                    this.toggleCheckbox "catLifestyle" "indoor"
                                  )
                                }}
                              />
                              <span>Indoor only</span>
                            </label>
                            <label
                              class="ExampleSheetWithKeyboard-checkboxLabel"
                            >
                              <input
                                type="checkbox"
                                checked={{includes this.catLifestyle "outdoor"}}
                                {{on
                                  "change"
                                  (fn
                                    this.toggleCheckbox "catLifestyle" "outdoor"
                                  )
                                }}
                              />
                              <span>Outdoor access</span>
                            </label>
                          </div>
                        </div>

                        {{! Description }}
                        <div
                          class="ExampleSheetWithKeyboard-field fieldType-description"
                        >
                          <label
                            for="cat-description"
                            class="ExampleSheetWithKeyboard-label"
                          >
                            Describe Your Ideal Cat
                          </label>
                          <p class="ExampleSheetWithKeyboard-labelDescription">
                            In your own words, describe what makes your perfect
                            feline companion.
                          </p>
                          <textarea
                            class="ExampleSheetWithKeyboard-textarea"
                            id="cat-description"
                            name="catDescription"
                            rows="6"
                            placeholder="Tell us about your dream cat's personality, quirks, and what kind of bond you hope to share..."
                            {{on
                              "input"
                              (fn this.updateFormField "catDescription")
                            }}
                          >{{this.catDescription}}</textarea>
                        </div>
                      </div>
                    </div>
                  </root.ScrollView>
                </view.Content>
              </root.View>
            </root.Portal>
          </DSheetWithKeyboard.Root>
        </:sample>
      </StyleguideComponent> --}}
    </StyleguideExample>
  </template>
}
