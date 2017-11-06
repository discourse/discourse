require 'rails_helper'
require 'unicorn/unicorn_json_log_formatter'

RSpec.describe UnicornJSONLogFormatter do
  context 'when message is an exception' do
    it 'should include the backtrace' do
      freeze_time do
        begin
          raise 'boom'
        rescue => e
          error = e

          output = described_class.new.call(
            'INFO',
            Time.zone.now,
            '',
            e
          )
        end

        output = JSON.parse(output)

        expect(output["severity"]).to eq('INFO')
        expect(output["datetime"]).to be_present
        expect(output["progname"]).to eq('')
        expect(output["pid"]).to be_present
        expect(output["message"]).to match(/boom:.*/)
      end
    end
  end
end
