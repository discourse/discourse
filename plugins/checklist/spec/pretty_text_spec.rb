# frozen_string_literal: true

describe PrettyText do
  describe "markdown it" do
    it "can properly bake boxes with offsets" do
      md = <<~MD
        [ ],[x],[X] are all checkboxes
        `[ ]` [x](hello) *[ ]* **[ ]** _[ ]_ __[ ]__ ~~[ ]~~ [] are not checkboxes
      MD

      cooked = PrettyText.cook(md)

      # Should have 3 checkboxes with offsets ([] empty is not a checkbox)
      expect(cooked.scan("chcklst-box").count).to eq(3)
      expect(cooked).to include('data-chk-off="0"') # [ ] at position 0
      expect(cooked).to include('data-chk-off="4"') # [x] at position 4
      expect(cooked).to include('data-chk-off="8"') # [X] at position 8
    end

    it "assigns correct offsets to checkboxes in list" do
      md = <<~MD
        - [ ] first
        - [x] second
        - [ ] third
      MD

      cooked = PrettyText.cook(md)

      expect(cooked).to include('data-chk-off="2"') # [ ] after "- "
      expect(cooked).to include('data-chk-off="14"') # [x] after "- " on line 2
      expect(cooked).to include('data-chk-off="27"') # [ ] after "- " on line 3
    end

    it "does not treat escaped brackets as checkboxes" do
      md = <<~MD
        \\[x] escaped opening bracket
        [x\\] escaped closing bracket
        \\[x\\] both brackets escaped
        \\[ ] escaped empty checkbox
        [x] real checkbox
      MD

      cooked = PrettyText.cook(md)

      expect(cooked.scan("chcklst-box").count).to eq(1)
      expect(cooked).to include("[x] escaped opening bracket")
      expect(cooked).to include("[x] escaped closing bracket")
      expect(cooked).to include("[x] both brackets escaped")
      expect(cooked).to include("[ ] escaped empty checkbox")
      expect(cooked).to include('class="chcklst-box checked fa fa-square-check-o fa-fw"')
    end

    it "handles escaped checkbox followed by real checkbox" do
      md = <<~MD
        \\[x] hello [x] world
      MD

      cooked = PrettyText.cook(md)

      expect(cooked.scan("chcklst-box").count).to eq(1)
      expect(cooked).to include("[x] hello")
      expect(cooked).to include('class="chcklst-box checked fa fa-square-check-o fa-fw"')
    end

    it "skips checkboxes inside code blocks" do
      md = <<~MD
        [ ] real checkbox
        ```
        [ ] in code block
        ```
        [x] another real
      MD

      cooked = PrettyText.cook(md)

      expect(cooked.scan("chcklst-box").count).to eq(2)
      expect(cooked).to include("[ ] in code block") # inside <code>
    end

    it "assigns correct offsets skipping code block checkboxes" do
      md = <<~MD
        ```ruby
        # This [ ] should not be a checkbox
        end
        ```

        [ ] real checkbox
      MD

      cooked = PrettyText.cook(md)

      # Only 1 checkbox (the real one after code block)
      expect(cooked.scan("chcklst-box").count).to eq(1)

      # The code block content should remain as text
      expect(cooked).to include("[ ] should not be a checkbox")

      # The real checkbox should have correct offset (position 53)
      # ```ruby\n (8) + # This [ ]... (36) + end\n (4) + ```\n (4) + \n (1) = 53
      expect(cooked).to include('data-chk-off="53"')
    end

    it "handles tilde-fenced code blocks" do
      md = <<~MD
        ~~~
        [ ] inside tilde fence
        ~~~

        [ ] outside
      MD

      cooked = PrettyText.cook(md)

      expect(cooked.scan("chcklst-box").count).to eq(1)
      expect(cooked).to include("[ ] inside tilde fence") # inside <code>
      expect(cooked).to include('data-chk-off="32"') # real checkbox at position 32
    end

    it "handles multiple code blocks" do
      md = <<~MD
        [ ] before
        ```
        [ ] code1
        ```
        [ ] middle
        ```
        [ ] code2
        ```
        [ ] after
      MD

      cooked = PrettyText.cook(md)

      # 3 real checkboxes: before, middle, after
      expect(cooked.scan("chcklst-box").count).to eq(3)

      # Check correct offsets
      # [ ] before\n (11) + ```\n (4) + [ ] code1\n (10) + ```\n (4) = 29
      # then + [ ] middle\n (11) + ```\n (4) + [ ] code2\n (10) + ```\n (4) = 58
      expect(cooked).to include('data-chk-off="0"') # [ ] before
      expect(cooked).to include('data-chk-off="29"') # [ ] middle
      expect(cooked).to include('data-chk-off="58"') # [ ] after
    end

    it "skips checkboxes inside inline code" do
      md = "`[ ]` is code, [ ] is real"

      cooked = PrettyText.cook(md)

      # Only 1 checkbox (the real one after inline code)
      expect(cooked.scan("chcklst-box").count).to eq(1)
      expect(cooked).to include("[ ]</code>") # inline code preserved
      # Position: `[ ]` (5) + " is code, " (10) = 15
      expect(cooked).to include('data-chk-off="15"')
    end

    it "handles mixed inline code and checkboxes" do
      md = "[ ] first `[ ]` code [ ] second `[x]` more [ ] third"

      cooked = PrettyText.cook(md)

      # 3 real checkboxes
      expect(cooked.scan("chcklst-box").count).to eq(3)
      # Positions: 0, then after "`[ ]` code " (16+5=21), then after "`[x]` more " (another 16)
      expect(cooked).to include('data-chk-off="0"')
      expect(cooked).to include('data-chk-off="21"')
      expect(cooked).to include('data-chk-off="43"')
    end
  end
end
