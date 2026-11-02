# frozen_string_literal: true
RSpec.describe TimeHelpers do
  include TimeHelpers

  describe "#freeze_time" do
    it "preserves fractional seconds and offsets across repeated freezes" do
      target = DateTime.iso8601("2024-02-29T10:11:12.123456+09:30")
      freeze_time(target)
      expect(Time.now.to_r).to eq(target.to_time.to_r)
      expect(DateTime.now).to eq(target)
      expect(DateTime.now.offset).to eq(target.offset)
      expect(Time.now.utc_offset).to eq(target.to_time.utc_offset)
      expect(Date.today).to eq(target.to_date)
      expect(TrackTimeStub.stubbed).to eq(true)
      later = target + Rational(1, 86_400)
      freeze_time(later)
      expect(Time.now.to_r).to eq(later.to_time.to_r)
      unfreeze_time
      expect(TrackTimeStub.stubbed).to eq(false)
    end

    it "restores the clock after a block raises and rejects nested freezing" do
      target = Time.utc(2014, 8, 26, 12)
      expect do
        freeze_time(target) do
          expect { freeze_time(target) {} }.to raise_error("nested freeze time not supported")
          raise "Clock block failed"
        end
      end.to raise_error("Clock block failed")
      expect(TrackTimeStub.stubbed).to eq(false)
      expect(Time.now).not_to eq(target)
    end

    it "keeps every background clock read valid while stubs change" do
      target = Time.utc(2014, 8, 26, 12)
      finished = false
      errors = Queue.new
      trace =
        TracePoint.new(:call, :c_call) { |event| Thread.pass if event.path.include?("/mocha/") }
      reader =
        Thread.new do
          until finished
            time = Time.now
            datetime = DateTime.now
            date = Date.today
            unless Time === time && DateTime === datetime && Date === date
              raise "Clock returned an invalid value"
            end
            Thread.pass
          end
        rescue Exception => error
          errors << [error.class.name, error.message]
        end
      trace.enable
      20.times do
        freeze_time(target)
        unfreeze_time
      end
      finished = true
      reader.join
      trace.disable
      observed_errors = []
      observed_errors << errors.pop until errors.empty?
      expect(observed_errors).to eq([])
    ensure
      finished = true
      reader&.join
      trace&.disable
      unfreeze_time
    end
  end
end
