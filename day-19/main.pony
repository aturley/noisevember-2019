use "buffered"
use "collections"
use "files"
use "itertools"
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

class Glisson
  let _freq_line: Line
  let _sine: SineGen

  new create(start_freq:F64, end_freq: F64, transition_samples: USize, sample_rate: SampleRate) =>
    _freq_line = Line(start_freq, end_freq, transition_samples)
    _sine = SineGen(_freq_line, sample_rate.f64())

  fun ref next() =>
    _freq_line.next()
    _sine.next()

  fun apply(): F64 =>
    _sine()

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

primitive GlissonCloud
  fun apply(density: F64, start_end_time: (F64, F64), dur_band: (F64, F64),
    targets: Array[F64], rand: Random, sample_rate: SampleRate,
    l_track: Track, r_track: Track)
  =>
    for _ in Range[F64](0, density * (start_end_time._2 - start_end_time._1)) do
      let glisson_dur = RandInRange(rand, dur_band._1, dur_band._2)
      let samples = sample_rate.samples_from_seconds(glisson_dur).usize()

      let target: F64 = try targets(rand.int[USize](targets.size()))? else 0 end

      let start = RandInRange(rand, target / 1.1, target * 1.1)

      let glisson = Glisson(start, target, samples, sample_rate)

      let gs = PlayFor(glisson, samples)
      let gse = QuasiGausianEnvelope(gs, 200, 200)

      let pos = sample_rate.samples_from_seconds(RandInRange(rand, start_end_time._1, start_end_time._2)).usize()

      l_track.add_samples(pos, gse, 0.05)
      r_track.add_samples(pos, gse, 0.05)
    end

actor Main
  new create(env: Env) =>
    let berlin_aiff_data: Array[U8] val = try
      let berlin: Array[U8] trn = recover Array[U8] end
      match OpenFile(FilePath(env.root as AmbientAuth, "berlin.aiff")?)
      | let f: File =>
        while f.errno() is FileOK do
          berlin.append(f.read(1024))
        end
        consume berlin
      else
        error
      end
    else
      return
    end

    let rand = Rand

    let reader: Reader ref = Reader

    let berlin = try
      let remaining_data = ReadFormChunk(berlin_aiff_data, reader)?

      (let num_channels, let sample_size) = ReadCommonChunk(remaining_data, reader)?

      ReadSoundDataChunk(reader, num_channels, sample_size)?
    else
      [[F64(0)]; [F64(0)]]
    end

    let sample_rate = SampleRate(44100)

    let l_track = Track
    let r_track = Track

    let things_mentioned: USize = 177

    try
      let l_sampler = Sampler(berlin(0)?)

      let slow_berlins = [l_sampler(0, 1, 100000); l_sampler(0, 1, 90000); l_sampler(0, 1, 80000); l_sampler(0, 1, 70000)]

      let fast_be = QuasiGausianEnvelope(l_sampler(0, 0.3, 6000), 200, 200)

      for x in Range(0, 1_100_000, 4000) do
        let a = (x.f64() * F64.pi() * 2) / 1_100_000
        let pan = (a.sin() + 1) / 2

        let slow_berlin = try slow_berlins(rand.int[USize](slow_berlins.size()))? else [as F64: 0] end

        let swing = rand.int[USize](3500)

        l_track.add_samples(x + swing, slow_berlin, 0.15 * pan)
        r_track.add_samples(x + swing, slow_berlin, 0.15 * (1 - pan))
      end

      for x in Range(0, 1_000_000,  (1_000_000 - 1) / things_mentioned) do
        let pan = rand.real()
        l_track.add_samples(40_000 + x, fast_be, 0.1 * pan)
        r_track.add_samples(40_000 + x, fast_be, 0.1 * (1 - pan))
      end

      // harry truman inaguration 1949-01-20
      // china's under martial law 1989-05-20
      // "rock-and-roller cola wars" is hard to quantify
      let days_from_start_to_finish: USize = 14_731

      let berlin_l_start: USize = 1_130_000

      let berlin_r_start = berlin_l_start + days_from_start_to_finish + berlin(0)?.size()

      l_track.add_samples(berlin_l_start, berlin(0)?)
      l_track.add_samples(berlin_l_start + sample_rate.samples_from_seconds(0.1949), berlin(0)?)
      r_track.add_samples(berlin_r_start, berlin(0)?)
      r_track.add_samples(berlin_r_start + sample_rate.samples_from_seconds(0.1989), berlin(0)?)

      let reverse_berlin_start = berlin_r_start + berlin(0)?.size() + days_from_start_to_finish

      let reverse_berlin = berlin(0)?.reverse()

      l_track.add_samples(reverse_berlin_start, reverse_berlin)
      r_track.add_samples(reverse_berlin_start, reverse_berlin)

      let clipped_berlin = Array[F64](berlin(0)?.size())

      for s in berlin(0)?.values() do
        let ns: F64 = if s < 0 then
          -1
        else
          1
        end

        clipped_berlin.push(ns)
      end

      let clipped_berlin_start = reverse_berlin_start + berlin(0)?.size() + days_from_start_to_finish

      l_track.add_samples(clipped_berlin_start, clipped_berlin, 0.5)
      r_track.add_samples(clipped_berlin_start, clipped_berlin, 0.5)

      env.err.print("clipped_berlin.size()=" + clipped_berlin.size().string())
    end

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
