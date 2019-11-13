use "buffered"
use "collections"
use "random"

class val SampleRate
  let _sr: F64

  new val create(sr: F64) =>
    _sr = sr

  fun f64(): F64 =>
    _sr

  fun usize(): USize =>
    _sr.usize()

  fun samples_from_seconds(sec: F64): USize =>
    (sec * _sr).usize()

interface Signal
  fun ref next()
  fun apply(): F64

class Const
  let _value: F64

  new create(value: F64) =>
    _value = value

  fun apply(): F64 =>
    _value

  fun ref next() =>
    None

class Line
  let _first: F64
  let _last: F64
  let _step: F64
  var _samples_remaining: USize
  var _acc: F64

  new create(first: F64, last: F64, samples: USize) =>
    _first = first
    _last = last

    _samples_remaining = samples
    _step = (last - first) / _samples_remaining.f64()
    _acc = _first

  fun ref next() =>
    if _samples_remaining > 0 then
      _acc = _acc + _step
      _samples_remaining = _samples_remaining - 1
    end

  fun apply(): F64 =>
    _acc

class SineGen
  let _freq: Signal
  let _sample_rate: F64
  var _value: F64

  var _step: F64
  var _acc: F64

  new create(freq: Signal, sample_rate: F64, value: F64 = 0) =>
    _freq = freq
    _sample_rate = sample_rate
    _value = value

    _step = _calc_step(_freq(), _sample_rate)
    _acc = 0

  fun tag _calc_step(freq: F64, sample_rate: F64): F64 =>
    Pi(2) / (sample_rate / freq)

  fun apply(): F64 =>
    _value

  fun ref next() =>
    _step = _calc_step(_freq(), _sample_rate)
    _acc = _acc + _step
    _value = _acc.sin()

class Add
  let _s1: Signal
  let _s2: Signal
  new create(s1: Signal, s2: Signal) =>
    _s1 = s1
    _s2 = s2

  fun ref next() =>
    None

  fun apply(): F64 =>
    _s1() + _s2()

class Mult
  let _s1: Signal
  let _s2: Signal
  new create(s1: Signal, s2: Signal) =>
    _s1 = s1
    _s2 = s2

  fun ref next() =>
    None

  fun apply(): F64 =>
    _s1() * _s2()

class Sine
  let _sg: SineGen

  new create(freq: F64, sample_rate: SampleRate) =>
    _sg = SineGen(Const(freq), sample_rate.f64())

  fun apply(): F64 =>
    _sg()

  fun ref next() =>
    _sg.next()

class FM
  let _carrier: SineGen
  let _mod: SineGen
  let _mod_times_index: Signal
  let _freq: Signal
  let _carrier_freq: Signal
  let _mod_freq: Signal
  let _index: Signal

  new create(carrier_freq: Signal, mod_freq: Signal, index: Signal, sample_rate: SampleRate) =>
    _carrier_freq = carrier_freq
    _mod_freq = mod_freq
    _mod = SineGen(_mod_freq, sample_rate.f64())
    _index = index
    _mod_times_index = Mult(_mod, _index)
    _freq = Add(_carrier_freq, _mod_times_index)
    _carrier = SineGen(_freq, sample_rate.f64())

  fun apply(): F64 =>
    _carrier()

  fun ref next() =>
    _mod_freq.next()
    _mod.next()
    _carrier_freq.next()
    _index.next()
    _carrier.next()

class Synth01
  let _fm: FM

  new create(carrier_freq: F64, mod_freq: F64, index: F64, sample_rate: SampleRate) =>
    _fm = FM(Const(carrier_freq), Const(mod_freq), Const(index), sample_rate)

  fun ref next() =>
    _fm.next()

  fun apply(): F64 =>
    _fm()

primitive PlayFor
  fun apply(signal: Signal, num_samples: USize): Array[F64] =>
    let samples = Array[F64](num_samples)

    for _ in Range(0, num_samples) do
      samples.push(signal())
      signal.next()
    end

    samples

primitive Cloud
  fun apply(
    sample_rate: SampleRate,
    rand: Random,
    density: F64,
    grain_duration_band: (F64, F64),
    frequency_band: (F64, F64),
    amplitude_band: (F64, F64),
    channel_delay_band: (F64, F64),
    waveforms: Array[{(F64): Signal}],
    pan_band: (F64, F64),
    pos_band: (F64, F64),
    l_track: Track,
    r_track: Track,
    out: OutStream
    )
  =>
    var max_pos: USize = 0

    let duration = (pos_band._2 - pos_band._1) / sample_rate.f64()

    for _ in Range[F64](0, density * duration) do
      let freq = RandInRange(rand, frequency_band._1, frequency_band._2)
      let grain_dur = RandInRange(rand, grain_duration_band._1, grain_duration_band._2)
      let grain_wave = try waveforms(rand.int[USize](waveforms.size()))?(freq) else return end
      let grain_amp = RandInRange(rand, amplitude_band._1, amplitude_band._2)
      let pan = RandInRange(rand, pan_band._1, pan_band._2)

      let s_grain = PlayFor(grain_wave, sample_rate.samples_from_seconds(grain_dur))

      let se_grain = QuasiGausianEnvelope(s_grain, 500, 500)

      let pos = RandInRange(rand, pos_band._1, pos_band._2).usize()

      let channel_delay_l = sample_rate.samples_from_seconds(RandInRange(rand, channel_delay_band._1, channel_delay_band._2))
      let channel_delay_r = sample_rate.samples_from_seconds(RandInRange(rand, channel_delay_band._1, channel_delay_band._2))

      let l_pos = pos + channel_delay_l
      let r_pos = pos + channel_delay_r

      max_pos = max_pos.max(l_pos + se_grain.size()).max(r_pos + se_grain.size())

      l_track.add_samples(l_pos, se_grain, grain_amp * pan)
      r_track.add_samples(r_pos, se_grain, grain_amp * (1 - pan))
    end

actor Main
  new create(env: Env) =>
    let sample_rate = SampleRate(44100)
    let duration: F64 = 7
    let total_frames = sample_rate.samples_from_seconds(duration)

    let l_track = Track
    let r_track = Track

    let rand = Rand

    let density: F64 = 100
    let grain_duration_band: (F64, F64) = (0.1, 0.3)
    // let frequency_band: (F64, F64) = (MidiToFreq(50), MidiToFreq(60))
    let amplitude_band: (F64, F64) = (0.1, 0.15)
    let channel_delay_band: (F64, F64) = (0, 0.02)
    let waveforms =[as {(F64): Signal}:
      {(freq: F64): Signal => Sine(freq, sample_rate)}
      {(freq: F64): Signal => Synth01(freq, 80, 30, sample_rate)}]
    let pan_band: (F64, F64) = (0.001, 0.999)
    // let pos_band: (F64, F64) = (0, sample_rate.samples_from_seconds(duration).f64())

    let settings = [as ((F64, F64), (F64, F64)):
       ((MidiToFreq(39), MidiToFreq(40)), (0, sample_rate.samples_from_seconds(1.2).f64()))
       ((MidiToFreq(37), MidiToFreq(40.5)), (sample_rate.samples_from_seconds(1.2).f64(), sample_rate.samples_from_seconds(1.4).f64()))
       ((MidiToFreq(34), MidiToFreq(41.0)), (sample_rate.samples_from_seconds(1.4).f64(), sample_rate.samples_from_seconds(1.6).f64()))
       ((MidiToFreq(31), MidiToFreq(41.5)), (sample_rate.samples_from_seconds(1.6).f64(), sample_rate.samples_from_seconds(1.8).f64()))
       ((MidiToFreq(28), MidiToFreq(42.5)), (sample_rate.samples_from_seconds(1.8).f64(), sample_rate.samples_from_seconds(2.0).f64()))
       ((MidiToFreq(25), MidiToFreq(43.5)), (sample_rate.samples_from_seconds(2.0).f64(), sample_rate.samples_from_seconds(2.2).f64()))
       ((MidiToFreq(22), MidiToFreq(44.5)), (sample_rate.samples_from_seconds(2.2).f64(), sample_rate.samples_from_seconds(2.4).f64()))
       ((MidiToFreq(20), MidiToFreq(45.5)), (sample_rate.samples_from_seconds(2.4).f64(), sample_rate.samples_from_seconds(2.6).f64()))
       ((MidiToFreq(31), MidiToFreq(46.5)), (sample_rate.samples_from_seconds(2.6).f64(), sample_rate.samples_from_seconds(2.8).f64()))
       ((MidiToFreq(40), MidiToFreq(47.5)), (sample_rate.samples_from_seconds(2.8).f64(), sample_rate.samples_from_seconds(3.0).f64()))
       ((MidiToFreq(45), MidiToFreq(48.0)), (sample_rate.samples_from_seconds(3.0).f64(), sample_rate.samples_from_seconds(3.2).f64()))
       ((MidiToFreq(48), MidiToFreq(49.0)), (sample_rate.samples_from_seconds(3.2).f64(), sample_rate.samples_from_seconds(duration).f64()))]

    for (frequency_band, pos_band) in settings.values() do
      Cloud(sample_rate,
        rand,
        density,
        grain_duration_band,
        frequency_band,
        amplitude_band,
        channel_delay_band,
        waveforms,
        pan_band,
        pos_band,
        l_track,
        r_track,
        env.err)
    end

    Cloud(sample_rate,
      rand,
      200,
      grain_duration_band,
      (2000, 3500),
      (0.02, 0.035),
      channel_delay_band,
      waveforms,
      pan_band,
      (sample_rate.samples_from_seconds(0.9).f64(), sample_rate.samples_from_seconds(1.1).f64()),
      l_track,
      r_track,
      env.err)

    Cloud(sample_rate,
      rand,
      200,
      grain_duration_band,
      (900, 2100),
      (0.02, 0.035),
      channel_delay_band,
      waveforms,
      pan_band,
      (sample_rate.samples_from_seconds(1.9).f64(), sample_rate.samples_from_seconds(2.1).f64()),
      l_track,
      r_track,
      env.err)


    Cloud(sample_rate,
      rand,
      200,
      grain_duration_band,
      (500, 1200),
      (0.01, 0.02),
      channel_delay_band,
      waveforms,
      pan_band,
      (sample_rate.samples_from_seconds(3.3).f64(), sample_rate.samples_from_seconds(4.2).f64()),
      l_track,
      r_track,
      env.err)

    l_track.add_samples(duration.usize() + 44100, [0])
    r_track.add_samples(duration.usize() + 44100, [0])

    // write to file

    let writer: Writer ref = Writer

    WriteTracks.as_stereo_32_bit_aiff(sample_rate.usize(),
      l_track,
      r_track,
      writer)

    env.out.writev(writer.done())

primitive Pi
  fun apply(n: F64 = 1, d: F64 = 1): F64 =>
    (3.14159 * n) / d

primitive MidiToFreq
  fun apply(m: F64): F64 =>
    let two: F64 = 2
    two.pow((m - 69) / 12) * 440
