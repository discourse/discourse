# frozen_string_literal: true

module DiscourseAi
  module Agents
    class Summarizer < Agent
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are an advanced summarization bot that generates concise, coherent summaries of provided text.
          You are also capable of enhancing an existing summaries by incorporating additional posts if asked to.

          - Only include the summary, without any additional commentary.
          - You understand and generate Discourse forum Markdown; including links, _italics_, **bold**.
          - Maintain the original language of the text being summarized.
          - Aim for summaries to be 400 words or less.
          - Each post is formatted as "(<POST_NUMBER> <USERNAME> said: <MESSAGE>"
          - Cite specific noteworthy posts using the format [DESCRIPTION]({resource_url}/POST_NUMBER)
          - Example: link to the 6th post by jane: [agreed with]({resource_url}/6)
          - Example: link to the 13th post by joe: [joe]({resource_url}/13)
          - When formatting usernames use [USERNAME]({resource_url}/POST_NUMBER)

          Format your response as a JSON object with a single key named "summary", which has the summary as the value.
          Your output should be in the following format:
          
          {"summary": "xx"}

          Where "xx" is replaced by the summary.
          reply with valid JSON only
        PROMPT
      end

      def response_format
        [{ "key" => "summary", "type" => "string" }]
      end

      def examples
        [
          [
            <<~TEXT.strip,
              The discussion title is: How can users reset their password if they forgot their account's email address?.

              Here are the posts, inside <input></input> XML tags:

              <input>
                (1 chloe_dev said: I signed up here with an email alias and I can't remember which one I used. The password reset form only accepts an email address, so I'm effectively locked out. Is there any way to recover the account with just my username? (3 marco said: This depends on the `hide email address taken` site setting. When it's enabled (the default), the reset form only accepts an email address to prevent account enumeration. If an admin disables it, you can request a reset by typing your username instead. (4 chloe_dev said: Thanks, disabling that setting worked on my test site! Still, I think username-based resets should always be possible. Forgetting which alias you used is common if you use a unique address for every site. (6 tobias_m said: Keep in mind that disabling it lets anyone probe which email addresses are registered. A safer path is contacting a staff member, who can look up the account and update its email from the admin page. (7 marco said: Right, that trade-off is exactly why it ships enabled. There is an open feature request to support username-based resets without leaking whether an email exists.
              </input>

              Generate a concise, coherent summary of the text above.
              Maintain the original language.
            TEXT
            {
              summary:
                "The discussion covers how users can reset their password when they no longer remember which email address is tied to their account. [chloe_dev]({resource_url}/1) explains they registered with an email alias they can't recall, and the reset form only accepts an email address. [marco]({resource_url}/3) points out this is controlled by the `hide email address taken` site setting: when enabled (the default), only emails are accepted to prevent account enumeration, while disabling it allows resets by username.\n\nAfter [confirming the workaround]({resource_url}/4), chloe_dev argues that username-based resets should always be possible since forgetting a per-site alias is common. [tobias_m]({resource_url}/6) warns that disabling the setting lets anyone probe which emails are registered and recommends contacting staff instead, and [marco]({resource_url}/7) notes an open feature request to allow username-based resets without leaking account information.",
            }.to_json,
          ],
        ]
      end
    end
  end
end
